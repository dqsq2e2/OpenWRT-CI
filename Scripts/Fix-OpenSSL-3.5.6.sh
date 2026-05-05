#!/bin/bash
#
# 修复 OpenSSL 3.5.6 编译错误
# 错误：ossl_der_oid_id_aes128_wrap undeclared
# 方案：禁用有问题的 X9.42 KDF 模块
#

set -e

echo ">>> 正在修复 OpenSSL 3.5.6 编译错误..."

OPENSSL_MAKEFILE="package/libs/openssl/Makefile"

if [ ! -f "$OPENSSL_MAKEFILE" ]; then
    echo "❌ 错误：未找到 OpenSSL Makefile"
    exit 1
fi

# 恢复到 3.5.6（如果之前升级过）
sed -i 's/PKG_VERSION:=3\.5\.7/PKG_VERSION:=3.5.6/' "$OPENSSL_MAKEFILE"

# 检查是否已经禁用
if grep -q "no-kdf" "$OPENSSL_MAKEFILE"; then
    echo "ℹ X9.42 KDF 已经被禁用"
    exit 0
fi

# 在 CONFIGURE_ARGS 中添加 no-kdf
# 查找包含 "no-" 选项的行，在其后添加
if grep -q "CONFIGURE_ARGS.*no-" "$OPENSSL_MAKEFILE"; then
    # 在第一个包含 no- 的 CONFIGURE_ARGS 行末尾添加
    sed -i '/CONFIGURE_ARGS.*no-/s/$/ \\\n\tno-kdf/' "$OPENSSL_MAKEFILE"
    echo "✅ 已在 CONFIGURE_ARGS 中添加 no-kdf"
else
    # 在 CONFIGURE_ARGS 定义后添加新行
    sed -i '/^CONFIGURE_ARGS/a\\tno-kdf \\' "$OPENSSL_MAKEFILE"
    echo "✅ 已添加 no-kdf 到 CONFIGURE_ARGS"
fi

echo ""
echo "✅ OpenSSL 修复完成"
echo ""
echo "修复方案："
echo "  - 禁用 X9.42 KDF 模块（很少使用的密钥派生函数）"
echo "  - 避免编译有 bug 的 x942kdf.c 文件"
echo "  - 不影响常用的加密功能（TLS、AES、RSA 等）"
echo ""
echo "下一步："
echo "  1. 清理: rm -rf build_dir/target-*/openssl-3.5.6"
echo "  2. 编译: make package/libs/openssl/compile V=s"
echo ""
