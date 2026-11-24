---
name: wechat-minigame-filing
description: "End-to-end workflow for building, uploading, preparing compliance screenshots and self-audit reports, auto-filling the WeChat MP minigame pre-approval form (new-pre-approval-file), and guiding MIIT ICP filing for WeChat Mini Games. This skill should be used when the user asks to upload a WeChat Mini Game via DevTools CLI, complete WeChat Mini Game ICP filing or pre-approval qualification, generate compliant WeChat audit screenshots, or fill out the mp.weixin.qq.com minigame filing page."
---

# WeChat Mini Game Upload & Filing Workflow

Execute the end-to-end release, pre-approval qualification, and MIIT ICP filing workflow for WeChat Mini Games (`mp.weixin.qq.com`).

## Workflow Decision Tree

Identify the user's current stage and jump directly to the corresponding step:
- **Need to build or upload code to WeChat MP**: Start at **Stage 1**.
- **Need to generate《游戏自审自查报告》or compliant screenshots**: Start at **Stage 2**.
- **User provides `mp.weixin.qq.com/.../new-pre-approval-file` or requests `/browser` form filling**: Run **Stage 2** (if screenshots are not yet generated) then **Stage 3**.
- **User asks about MIIT ICP filing (`小程序备案`), SMS verification, or release gating**: Execute **Stage 4**.

---

## Stage 1: Build & Upload via WeChat DevTools CLI

Consult [CLI Upload & ICP Reference](./references/cli-upload-and-icp.md) for registry lookup commands and config checks.

1. **Verify WeChat build artifacts**:
   - Ensure the target directory contains `game.js`, `game.json` (`"deviceOrientation"` set properly), and `project.config.json` (`"compileType": "game"` and exact `appid`).
   - Confirm total package size does not exceed WeChat's 20 MB main-package limit.
   - Verify pure IAA games contain zero payment/IAP API calls.
2. **Locate DevTools CLI and check service port**:
   - Locate `cli.bat` under the WeChat DevTools installation directory.
   - Run `cli.bat islogin --token <CLI_TOKEN>`.
   - If the command reports `工具的服务端口已关闭`, instruct the user to open WeChat DevTools **设置 → 安全设置 → 开启服务端口** and provide the CLI token.
3. **Open project and upload**:
   - Execute `cli.bat open --project "<DIST_DIR>" --token <CLI_TOKEN>`.
   - Execute `cli.bat upload --project "<DIST_DIR>" -v "<VERSION>" -d "<DESC>" --token <CLI_TOKEN>`.
   - Confirm `√ upload` and report the uploaded package size.

---

## Stage 2: Generate Compliance Assets

Never reuse screenshots lacking the WeChat capsule or displaying a mismatched game name. Always obtain the **exact registered mini-game name** from the WeChat MP backend (Step 1 of `new-pre-approval-file`) before generating screenshots.

### 2.1 Self-Audit Report (《游戏自审自查报告》)
Run [render_self_audit_report.mjs](./scripts/render_self_audit_report.mjs) using [self-audit-report.template.html](./assets/self-audit-report.template.html):
```bash
node "<SKILL_DIR>/scripts/render_self_audit_report.mjs" \
  --game-name "<EXACT_GAME_NAME>" \
  --appid "<APPID>" \
  --version "<VERSION>" \
  --category "<CATEGORY>" \
  --subject "<SUBJECT_NAME>" \
  --theme "<THEME_SUMMARY>" \
  --out "<OUTPUT_HTML_PATH>"
```
Instruct the user to print (`Ctrl+P`) or sign the generated A4 HTML and upload a clear photo/scan if requested by the portal.

### 2.2 Compliant WeChat Audit Screenshots
Prepare at least **9 raw screenshots** covering:
- **Scenes** (`≥ 3`): Main screen, representative levels/modes.
- **Gameplay** (`≥ 3`): Core input loop, combat/collection feedback, level clear/rewards.
- **System 1 (Currency)** (`≥ 1`): Resource earning/spending screen.
- **System 2 (Items/Upgrades)** (`≥ 1`): Upgrades, artifacts, or skill tree screen.
- **System 3 (Settings)** (`≥ 1`): Audio/vibration settings screen (pass `-OverlayMode settings` or `"overlay": "settings"` in manifest JSON to synthesize a clean settings modal automatically if none exists).

Run [prepare_wechat_screenshots.ps1](./scripts/prepare_wechat_screenshots.ps1):
```powershell
powershell -ExecutionPolicy Bypass -File "<SKILL_DIR>/scripts/prepare_wechat_screenshots.ps1" `
  -GameName "<EXACT_GAME_NAME>" `
  -OutDir "<OUT_SCREENSHOT_DIR>" `
  -ManifestJson "<MANIFEST_JSON_PATH>"
```
Verify every generated PNG reports `✅` and falls strictly within **60 KB ~ 5 MB**.

---

## Stage 3: Auto-Fill `new-pre-approval-file` via Browser Subagent

Consult [Pre-Approval Form Guide](./references/new-pre-approval-file-guide.md) and [Copywriting Templates](./references/copywriting-templates.md) before invoking or messaging the `browser` subagent.

1. **Adapt text blocks**:
   - Populate templates from [copywriting-templates.md](./references/copywriting-templates.md) using the target game's GDD/docs.
   - Enforce minimum lengths: Scene `≥ 30` chars, Gameplay `≥ 50` chars, each System `≥ 30` chars (max `800`).
   - Run the forbidden-word check in [copywriting-templates.md](./references/copywriting-templates.md) to remove all payment/gambling/hyperbolic terms for IAA games.
2. **Handle authentication cleanly**:
   - Invoke `browser` subagent (`Model: "flash"`). If `BLOCKED / AUTH_REQUIRED`, ask the user to scan the WeChat QR code in the browser pane, then resume **the same `conversationId`** via `send_message`.
3. **Respect portal hard rules**:
   - **Minimum 3 systems**: Do NOT delete System 3 below 3 systems (`系统功能最少为三个`). Select `设置系统` for System 3 on pure single-player/IAA games.
   - **Optional fields**: Keep optional sections (背景/角色/NPC/情节/特点) at default `本游戏不涉及` unless screenshots for each enabled section are prepared.
4. **Stage upload files and save drafts**:
   - Copy all generated PNGs into `<Artifact Directory Path>/browser_sandbox/uploads/` using single-segment filenames immediately before calling `invoke_subagent` or `send_message` (the sandbox wipes `uploads/` on turn exit).
   - Instruct the subagent to save draft (`保存`) after filling text fields and after uploading screenshots, and to stop on Step 3 (`信息预览`) with zero `visibleErrs`.
   - **Never click the final submit button automatically**; leave the green `提交` button for user verification and manual submission.

---

## Stage 4: Guide MIIT ICP Filing & Final Release

Consult [CLI Upload & ICP Reference](./references/cli-upload-and-icp.md) §2 to brief the user on post-submission steps:
1. Confirm non-IAP casual games select **无需前置审批 / 无版号**.
2. Track the four MIIT stages: Platform Initial Review (1–2 business days) → **12381 MIIT SMS Verification (strictly within 24 hours)** → Provincial CA Final Approval → License number issued.
3. Remind the user to promote the uploaded version to **体验版** for real-device testing and click **提交审核** once the filing number activates.
