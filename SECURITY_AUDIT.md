# Grok CLI 源码安全审计报告（增量评审）

> 审计对象：[`xai-org/grok-build`](https://github.com/xai-org/grok-build)（Grok Code CLI 源码）
> 评审方式：增量评审，首版 commit `c68e39f` 已评审通过，本报告覆盖其后的 10 个
> `Synced from monorepo` commit，聚焦**数据泄露 / 源码上传 / RCE / 权限绕过**。
> 评审时间：2025-07-26
> 审计人：youfun（pi-agent 辅助）

## 审计范围

| commit | 说明 | 与本次 finding 关系 |
|---|---|---|
| `c68e39f` | Publish harness and TUI open-source（首版） | 已评审通过；**无 `export_github`，无此问题** |
| `8adf901` … `6e38642` | 9 个 monorepo sync | 未引入 `export_github` |
| `47348d1` | Synced from monorepo（**HEAD / 最新**） | **引入 `export_github`**（本报告核心 finding） |

`47348d1` 之后无后续 commit —— 即本报告所述缺陷为**仓库当前状态**。

## 总体结论

本批 commit 整体安全姿态在收紧：修复了 hook 重定向 SSRF、`rg --pre` 任意代码执行、
`env -S` 绕过、`Bash(git:*)` 链式前缀绕过、workspace file-reference 限制绕过、
acceptEdits 自动批准写 hook root 等真实可利用漏洞，方向正确。

但 `47348d1` 引入了一个首版不存在的"项目源码导出到 GitHub"功能（`export_github`），
其安全设计存在缺陷，构成数据泄露面。经反复校准（见"风险校准"一节），该缺陷的
**真实高危点不在"推到哪"，而在"推什么"**。

## 🔴 核心发现：`export_github` 默认 `.gitignore` 排除集过窄，导致密钥随正常导出外泄

### 位置
- `crates/codegen/xai-grok-workspace/src/export_github.rs`（`47348d1` 新增，753 行）
- `crates/codegen/xai-grok-workspace-types/src/rpc/export_github.rs`
- `crates/codegen/xai-grok-workspace/src/hub_server.rs`（dispatch 注册）

### 功能描述
`export_github` 是"把 grok 生成的项目发布到 GitHub 仓库"的 git push 功能。流程：

```
git init（若不存在）
  → git add -A                    // 全量暂存所有未被忽略的文件
  → git commit -m "Export from Grok"  // 作者硬编码 "Grok <grok-export@users.noreply.github.com>"
  → git remote set-url origin <url>  // 改写 origin 为 repo_full_name 派生的 URL
  → git push -u origin HEAD:main
```

`repo_full_name` 来源优先级（`resolve_repo_mapping`）：
**请求参数 > `.github_repo` 明文文件 > 报错**。

### 缺陷 1（高危，独立成立）：默认 `.gitignore` 排除集过窄

`export_github.rs` 的 `SEED_GITIGNORE` 仅排除：
```
node_modules/
.project_id
.github_repo
.env
.env.*
```

`git add -A` 会把**未被忽略的密钥文件**一并提交并推送，包括但不限于：
- `config.yml` / `config.json`（常含 DB 密码、API key）
- `secrets.json` / `credentials.json`
- `.aws/credentials` / `.aws/config`
- `.ssh/`（`id_rsa`、`id_ed25519` 等）
- `*.pem` / `*.key`
- `.git-credentials` / `.npmrc` / `.netrc`
- `*.kube/config`

### 为什么这是独立成立的高危
**不依赖任何攻击者行为、不依赖 prompt injection、不依赖模型知道仓库地址。**
用户在**正常使用**（自选自己的仓库、用自己的凭据）下导出项目，`git add -A` 就会把
`config.yml` 里的 DB 密码一起推到自己的 GitHub 仓库。若该仓库为 public，凭据即公开 →
下游可导致云账号被接管。

### 修复建议 1（最高 ROI，零判断成本）
扩展 `SEED_GITIGNORE`，默认排除常见密钥文件：
```rust
const SEED_GITIGNORE: &str = "\
node_modules/\n\
.project_id\n\
.github_repo\n\
.env\n\
.env.*\n\
.aws/\n\
.ssh/\n\
.git-credentials\n\
.npmrc\n\
.netrc\n\
*.pem\n\
*.key\n\
id_rsa*\n\
id_ed25519*\n\
credentials.json\n\
secrets.json\n\
.kube/config\n\
";
```
并在 push 前对即将提交的文件列表做一次"高风险扩展名/路径"扫描，命中即提示用户确认。

## 🟠 次要发现

### 缺陷 2：`set_remote` 改写 `origin` 无确认门
`set_remote`（`export_github.rs:272`）：若 `.git/config` 已有 `origin`，直接
`git remote set-url origin <url>` **覆盖**，不区分"推回原仓库"与"改写到一个新仓库"。

- 用户从私有仓库 `user/private-repo` clone 来的项目，`.git/config` 的 `origin` 被无视并改写。
- 一次带参请求即可把 origin 改写到别处，并回写 `.github_repo`。

**修复建议 2**：`set_remote` 改写 origin 到一个**与 `.github_repo` 记录不同**的仓库时，
必须经 TUI 确认；确认前不执行 `set-url` / `push`。

### 缺陷 3：`.github_repo` mapping 可被静默篡改
`.github_repo` 是无签名、无校验的明文文件，存储推送目标。任何对项目目录有写权限的进程
（包括被诱导执行一次写操作的 agent）都能改写它，把后续"无 `repo_full_name`"的导出
重定向到任意仓库。一次成功 export 后该文件被回写，形成**持久化重定向**。

**修复建议 3**：`.github_repo` 变更需用户确认；或对 mapping 做签名/绑定受信任配置。

### 缺陷 4：`export_github` RPC 无权限门控
`hub_server.rs` 的 dispatch 走 `dispatch_op::<ExportGithubReq>(params, &self.workspace, None)`，
`session_id=None`，**无 `ensure_*_enabled` 门控**（对比 `ClientFsListReq` 有
`ensure_client_fs_queries_enabled`），**不走 `AccessKind` 权限管理器**（只有 Bash/Edit/Write 走）。

**修复建议 4**：dispatch 加 `ensure_export_github_enabled`，对齐 `ClientFsListReq` 门控级别；
`repo_full_name` 必须命中用户预授权仓库集合，否则拒绝。

## 风险校准（重要：避免过强表述）

经反复核对，以下两个"看似高危"的路径**实际不成立或门槛很高**，不应作为 finding 主体：

### 校准 1：推到"攻击者仓库" —— ❌ 不可行
`export_github` **不注入 token**，push 认证靠用户环境已有的 git 凭据（`gh auth` /
credential helper）。推到 `attacker/exfil` 时用户凭据无写权限，push 直接
`Permission denied`。**此路径不成立。**

### 校准 2：模型默认不知道用户的公开仓库 —— ✅ 成立，限制风险
OSS 代码全树搜索：**没有任何"列举/发现用户 GitHub 仓库"的代码**（无 `list repos`、
无 `api.github`、无 GitHub OAuth/account linking）。CLI 本身不能查"用户有哪些 public
仓库"，模型工具面也无此能力。因此"私有 → 用户自己的 public 仓库"泄露路径需要满足：
1. 闭源 deploy 流让模型可填 `repo_full_name`（OSS 代码无法确认，可能由用户手选即安全）；
2. 模型从某处得知用户的一个 public 仓库名（对话泄露 / `package.json` / `.git/config` / README）；
3. 当前项目为私有且含未忽略密钥；
4. 用户凭据对该 public 仓库有 push 权限。

四条件同时满足才成立，门槛显著高于初版表述。

### 校准结论
**真正的独立高危是缺陷 1（默认 gitignore 过窄）**——它在用户正常自选仓库、
无任何攻击/注入的情况下即可导致凭据公开。其余缺陷（2/3/4）依赖 `repo_full_name`
来源不确定，定级为中。

## 已确认的安全修复（正向，本批 commit 做对的）

| commit | 修复 | 评价 |
|---|---|---|
| `8adf901` | SSRF via HTTP redirect in hook runner（`redirect(Policy::none())`） | ✅ 正确 |
| `47348d1` | acceptEdits 自动批准写 hook root（`shell_access.rs::edit_target_protection`） | ✅ 重要，堵持久化逃逸链 |
| `47348d1` | workspace file-reference 限制绕过（`confine_to_workspace_root`） | ✅ 正确 |
| `a5727c5` | `Bash(git:*)` 链式前缀绕过（词边界 + 合取判定） | ✅ 扎实 |
| `3af4d5d` | `rg --pre` / `env -S` / `kubectl kubeconfig plugins` / `ps` env-dumping | ✅ 方向正确 |
| `47348d1` | managed-config 签名验证 arm（嵌入 prod `v1` 公钥） | ✅ 升级（但见下） |

## 待跟进（非阻断）

- **L1** managed-config 签名验证的**远程 kill-switch**（`signed_policy.rs::REMOTE_VERIFICATION_DISARMED`）：
  允许服务端远程关闭所有客户端签名验证。已做对的部分：仅 `settings_origin_trusted` 时可 disarm，
  不可信 proxy 无法 disarm keyed 客户端。残留风险：服务端被入侵即可远程降级所有客户端；
  建议 disarm 加时效绑定 + 客户端可见告警。
- **L2** `coding_data_retention_opt_out` 是否真正 gate `repo_changes` archive 上传：
  评审未在 OSS 代码里闭合此调用链（trace upload 走 `gcs_config`，未见 opt-out 显式短路
  repo archive 上传）。建议追完整调用链确认 opt-out 时不传源码 archive。
- **L3** marketplace git URL 校验（`69f0ba8`）：建议显式限制 scheme 为 `https`，禁 `file://`/`ssh://`。

## 修复优先级

1. 🔴 扩展默认 `SEED_GITIGNORE`（缺陷 1）—— 最高 ROI，独立阻断凭据外泄。
2. 🟠 `set_remote` 改写 origin 确认门（缺陷 2）。
3. 🟠 `.github_repo` 变更确认/签名（缺陷 3）。
4. 🟠 `export_github` RPC 权限门控 + 仓库预授权白名单（缺陷 4）。