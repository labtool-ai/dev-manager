#!/usr/bin/env bash
#
# 公开示例:复制为 scripts/release.sh(已被 .gitignore 忽略),填入你自己的
# TEAM_ID / Apple ID / FEED_BASE_URL 后使用。也可用环境变量覆盖:
#   TEAM_ID=XXXX FEED_BASE_URL=https://you.example.com/devmanager ./scripts/release.sh
#
# DevManager 一键发版:构建 → Developer ID 签名 → 公证 → staple → 打包 → Sparkle 签名 → 生成 appcast
#
# 前置(一次性):
#   1. xcodegen / xcodebuild 可用
#   2. keychain 里已装 "Developer ID Application: <Your Name> (<YOUR_TEAM_ID>)"
#   3. 已跑 `xcrun notarytool store-credentials "devmanager-notary" ...`(见下 NOTARY_PROFILE)
#   4. 已跑 Sparkle 的 generate_keys(私钥在 keychain,公钥已写进 project.yml 的 SUPublicEDKey)
#   5. 把下面 FEED_BASE_URL 改成你宝塔上放 appcast/安装包的公网目录
#
# 每次发版:
#   - 先把 project.yml 里的 MARKETING_VERSION 抬一位(如 0.1.0 → 0.2.0)
#   - 跑 ./scripts/release.sh
#   - 把 build/updates/ 里的 appcast.xml 和 DevManager-<版本>.zip 传到 FEED_BASE_URL 对应目录
#
set -euo pipefail

# ------- 配置 -------
APP_NAME="DevManager"
SCHEME="DevManager"
TEAM_ID="${TEAM_ID:-YOUR_TEAM_ID}"
NOTARY_PROFILE="devmanager-notary"
FEED_BASE_URL="${FEED_BASE_URL:-https://updates.example.com/devmanager}"   # ← appcast.xml 和 zip 的公网目录,必须和 project.yml 的 SUFeedURL 目录一致
# --------------------

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/$APP_NAME.xcarchive"
EXPORT="$BUILD/export"
UPDATES="$BUILD/updates"           # generate_appcast 扫描这个目录
mkdir -p "$UPDATES"

echo "▶ [1/7] 生成工程"
xcodegen generate >/dev/null

echo "▶ [2/7] Archive(Release)"
rm -rf "$ARCHIVE"
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -quiet

echo "▶ [3/7] 导出 Developer ID 签名 app"
rm -rf "$EXPORT"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT" \
  -exportOptionsPlist "$ROOT/scripts/ExportOptions.plist" \
  -quiet
APP="$EXPORT/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "   版本: $VERSION"

echo "▶ [4/7] 公证(notarytool,可能几分钟)"
NOTARIZE_ZIP="$BUILD/$APP_NAME-notarize.zip"
/usr/bin/ditto -c -k --keepParent "$APP" "$NOTARIZE_ZIP"
xcrun notarytool submit "$NOTARIZE_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$NOTARIZE_ZIP"

echo "▶ [5/7] staple(把公证票据钉进 app)"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "▶ [6/7] 打分发 zip → $UPDATES"
DIST_ZIP="$UPDATES/$APP_NAME-$VERSION.zip"
rm -f "$DIST_ZIP"
/usr/bin/ditto -c -k --keepParent "$APP" "$DIST_ZIP"

echo "▶ [7/7] 生成/更新 appcast(Sparkle 用 keychain 私钥签名)"
GEN_APPCAST="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*artifacts*sparkle*' -name generate_appcast 2>/dev/null | head -1)"
if [ -z "$GEN_APPCAST" ]; then
  echo "✗ 找不到 generate_appcast(先在 Xcode 里构建一次以解析 Sparkle SPM)"; exit 1
fi
"$GEN_APPCAST" --download-url-prefix "$FEED_BASE_URL/" "$UPDATES"

echo ""
echo "✅ 完成。上传这两样到 $FEED_BASE_URL/ :"
echo "   - $UPDATES/appcast.xml"
echo "   - $DIST_ZIP"
echo ""
echo "   确认 project.yml 的 SUFeedURL = $FEED_BASE_URL/appcast.xml"
