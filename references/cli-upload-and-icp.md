# 微信开发者工具 CLI 上传与工信部 ICP 备案指南

## 1. 微信开发者工具定位与上传前核查

### 1.1 定位安装路径与 `cli.bat`
Windows 常见路径及注册表查询命令：
```powershell
Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*", "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -like "*微信*开发者*" } |
  Select-Object DisplayName, UninstallString
```
`cli.bat` 与 `UninstallString`（`卸载微信开发者工具.exe`）位于同一安装目录下（常见为 `D:\Program Files (x86)\Tencent\微信web开发者工具\cli.bat` 或 `C:\Program Files (x86)\Tencent\微信web开发者工具\cli.bat`）。

### 1.2 工程合规核查清单
构建产物目录（如 `dist/wechat/`）必须具备：
1. `project.config.json`：`compileType` 必须为 `"game"`，`appid` 与目标微信小游戏 AppID 一致。
2. `game.json`：横版游戏配置 `"deviceOrientation": "landscape"`、`"showStatusBar": false`。
3. `game.js` 与静态资源：总包体体积须在微信小游戏主包限制内（≤ 20 MB，首包建议 ≤ 4 MB）。
4. 平台 API 隔离：使用 `wx` 全局对象（`wx.createCanvas`、`wx.getSystemInfoSync`、`wx.showShareMenu`、`wx.onShareAppMessage`、`wx.createRewardedVideoAd`），无任何未配置广告位导致的阻塞异常，纯 IAA 个人小游戏代码中严禁出现支付/内购 API。

### 1.3 服务端口开启与 CLI 上传命令
1. 检查登录态与服务端口：
   ```powershell
   & "<WECHAT_IDE_DIR>\cli.bat" islogin --token <CLI_TOKEN>
   ```
   若提示 `工具的服务端口已关闭`，引导用户在微信开发者工具顶部菜单开启：**【设置】➔【安全设置】➔【服务端口】开启**，并复制工具生成的 CLI Token（或在 MCP 中配置 `"<WECHAT_IDE_DIR>\\cli.bat"` + `["mcp", "--token=<CLI_TOKEN>"]`）。
2. 在工具中打开项目并上传代码：
   ```powershell
   & "<WECHAT_IDE_DIR>\cli.bat" open --project "<DIST_WECHAT_DIR>" --token <CLI_TOKEN>
   & "<WECHAT_IDE_DIR>\cli.bat" upload --project "<DIST_WECHAT_DIR>" -v "<VERSION>" -d "<DESC>" --token <CLI_TOKEN>
   ```
   上传成功后确认控制台返回 `√ upload` 与包体大小统计表。

---

## 2. 工信部小程序 ICP 备案全流程

### 2.1 免版号与前置审批判断
| 游戏商业模式 | 适用主体 | 游戏版号（ISBN） | 前置审批选择 |
| :--- | :--- | :--- | :--- |
| 纯广告变现 / 纯免费单机（IAA，无内购） | 个人 / 企业均可 | **无需版号** | 选择 **【否 / 无前置审批项】** |
| 含游戏内充值 / 虚拟支付（IAP） | 仅限企业 / 个体户 | **必须具备版号** | 必须上传版号核发单及批文 |

### 2.2 备案材料准备
* **个人主体**：本人身份证正反面原件照（四角完整清晰）、本人微信人脸识别核验、实名手机号、不同号码的应急联系人手机号。
* **企业主体**：营业执照彩色扫描件、法人身份证正反面、主体/小程序负责人人脸识别与手机号。
* **《游戏自审自查报告》**：使用本技能 `scripts/render_self_audit_report.mjs` 生成 A4 HTML，打印签字/按手印或加盖公章后拍照上传（若页面仅走电子签流程则配合微信扫码电子签）。

### 2.3 备案四阶段与关键卡点
```text
1. 后台提交初审 ➔ 2. 腾讯平台初审（1~2 工作日）➔ 3. 工信部 12381 短信核验（24 小时内！）➔ 4. 省通管局终审下发备案号
```
* **关键提醒（必叮嘱用户）**：腾讯初审通过后，工信部（发件人 `12381`）会向主体负责人手机发送 6 位核验短信及核验链接（`https://beian.miit.gov.cn`）。**必须在收到短信 24 小时内**登录链接完成手机号、身份证后 6 位及验证码核验；逾期未核验将自动退回，需重新排队提审。
* **上线收尾**：管局下发备案号（如 `粤ICP备XXXXXXXX号-1X`）后，在微信公众平台【版本管理】中选中已上传的开发版本，先设【体验版】扫码真机复测，再点击【提交审核】并发布上线。
