#!/usr/bin/env node
// 生成符合微信小游戏上线/备案规范的 A4 可打印《游戏自审自查报告》HTML
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const TEMPLATE_PATH = path.resolve(__dirname, '../assets/self-audit-report.template.html');

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (!key.startsWith('--')) continue;
    const val = argv[i + 1];
    if (!val || val.startsWith('--')) {
      throw new Error(`参数 ${key} 缺少取值`);
    }
    args[key.slice(2)] = val;
    i++;
  }
  return args;
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args['game-name'] || !args.appid || !args.out) {
    console.error(
      '用法: node render_self_audit_report.mjs --game-name <游戏名> --appid <AppID> --out <输出HTML路径> [--version V1.0.0] [--category 休闲益智类] [--subject 主体名称] [--theme 题材立意说明] [--iap]'
    );
    process.exit(1);
  }

  if (!fs.existsSync(TEMPLATE_PATH)) {
    console.error(`找不到模板文件: ${TEMPLATE_PATH}`);
    process.exit(1);
  }

  const isIap = args.iap === 'true' || args.iap === '1';
  const monetizationMode =
    args.monetization ||
    (isIap
      ? '合规内购与广告变现（已按国家规定接入版号与实名防沉迷）'
      : '纯广告激励变现（IAA），无游戏内道具充值与虚拟商城支付');
  const monetizationClause = isIap
    ? '本游戏已按国家新闻出版署与平台规范严格接入实名认证及未成年人消费限额控制，所有收费项目均明码标价、公开透明，绝无诱导消费陷阱'
    : '本游戏为纯单机休闲玩法，未接入任何形式的游戏内充值接口、虚拟货币支付或微交易商城，杜绝任何诱导消费、过度消费陷阱';

  const replacements = {
    GAME_NAME: escapeHtml(args['game-name']),
    APPID: escapeHtml(args.appid),
    VERSION: escapeHtml(args.version || 'V1.0.0'),
    MONETIZATION_MODE: escapeHtml(monetizationMode),
    MONETIZATION_CLAUSE: escapeHtml(monetizationClause),
    GAME_CATEGORY: escapeHtml(args.category || '休闲益智类小游戏'),
    SUBJECT_NAME: escapeHtml(args.subject || '本人/本单位'),
    THEME_SUMMARY: escapeHtml(
      args.theme || '游戏弘扬积极向上的健康文化与正向价值观，内容纯净益智'
    ),
    YEAR: String(args.year || new Date().getFullYear()),
  };

  let html = fs.readFileSync(TEMPLATE_PATH, 'utf8');
  for (const [key, value] of Object.entries(replacements)) {
    html = html.replaceAll(`{{${key}}}`, value);
  }

  const leftover = html.match(/\{\{[A-Z0-9_]+\}\}/g);
  if (leftover) {
    console.error(`模板存在未替换占位符: ${leftover.join(', ')}`);
    process.exit(1);
  }

  const outPath = path.resolve(args.out);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, html, 'utf8');
  console.log(`✅ 已生成自审自查报告: ${outPath}`);
}

main();
