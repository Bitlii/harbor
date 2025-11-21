#!/bin/bash
# 文件名: run_schema_upgrade.sh
# 用途: 按严格顺序执行所有 *_schema.up.sql 升级脚本, 在华为 GaussDB 初始化 Harbor v2.6.4 的数据库。
# 作者: Bitlii
# 使用方法: chmod +x run_schema_upgrade.sh && ./run_schema_upgrade.sh

set -euo pipefail   # 遇到任何错误立即退出


# ==================== 请修改以下配置 ====================
# gsql -h 101.89.150.213 -p 8002 -U root -W '******' -d harbor_registry
GSQL_CONN=(
    "gsql"
    "-d" "harbor_registry"        # 改成你要升级的目标库，比如 dwsdb、postgres、dw 等
    "-U" "root"                 # 改成有权限的用户，通常是 omm 或 root
    "-h" "101.89.150.213"           # 如果是本地 socket 可不写，远程就写主机IP
    "-p" "8002"                # 端口，默认 5432，集群可能不同
    "-W" "******"      # 如果需要交互式输入密码，删掉这行；如果想写死密码就打开
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # 脚本所在目录
LOG_DIR="${SCRIPT_DIR}/upgrade_logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/upgrade_${TIMESTAMP}.log"

# 记录已成功执行过的脚本（防止重复执行）
EXECUTED_MARKER="${SCRIPT_DIR}/.schema_upgrade_executed"

mkdir -p "$LOG_DIR"

# 颜色输出
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m' # No Color

log() {
    echo -e "$@" | tee -a "$LOG_FILE"
}

# ==================== 严格顺序执行的脚本列表 ====================
SQL_SCRIPTS=(
    "0001_initial_schema.up.sql"
    "0002_1.7.0_schema.up.sql"
    "0003_add_replication_op_uuid.up.sql"
    "0004_1.8.0_schema.up.sql"
    "0005_1.8.2_schema.up.sql"
    "0010_1.9.0_schema.up.sql"
    "0011_1.9.1_schema.up.sql"
    "0012_1.9.4_schema.up.sql"
    "0015_1.10.0_schema.up.sql"
    "0030_2.0.0_schema.up.sql"
    "0031_2.0.3_schema.up.sql"
    "0040_2.1.0_schema.up.sql"
    "0041_2.1.4_schema.up.sql"
    "0050_2.2.0_schema.up.sql"
    "0051_2.2.1_schema.up.sql"
    "0052_2.2.2_schema.up.sql"
    "0053_2.2.3_schema.up.sql"
    "0060_2.3.0_schema.up.sql"
    "0061_2.3.4_schema.up.sql"
    "0070_2.4.0_schema.up.sql"
    "0071_2.4.2_schema.up.sql"
    "0080_2.5.0_schema.up.sql"
    "0081_2.5.2_schema.up.sql"
    "0082_2.5.3_schema.up.sql"
    "0090_2.6.0_schema.up.sql"
    "0091_2.6.2_schema.up.sql"
)

# ==================== 开始执行 ====================
log "============================================================"
log "数据库结构升级开始 $(date '+%Y-%m-%d %H:%M:%S')"
log "目标库：${GSQL_CONN[2]}   用户：${GSQL_CONN[4]}"
log "日志文件：$LOG_FILE"
log "============================================================"

# 创建已执行标记文件（如果不存在）
touch "$EXECUTED_MARKER"

for script in "${SQL_SCRIPTS[@]}"; do
    script_path="${SCRIPT_DIR}/${script}"

    if [ ! -f "$script_path" ]; then
        log "${RED}错误：文件不存在 -> $script${NC}"
        exit 1
    fi

    # 检查是否已经执行过（防止重复执行）
    if grep -qxF "$script" "$EXECUTED_MARKER" 2>/dev/null; then
        log "${YELLOW}跳过（已执行）: $script${NC}"
        continue
    fi

    log "${GREEN}正在执行: $script${NC}"

    # 执行脚本并把输出实时写入日志
    if "${GSQL_CONN[@]}" -f "$script_path" -q -v ON_ERROR_STOP=1 >> "$LOG_FILE" 2>&1; then
        log "${GREEN}成功 $script${NC}"
        echo "$script" >> "$EXECUTED_MARKER"   # 标记为已执行
    else
        log "${RED}失败！！！ $script  执行出错，请查看上面日志${NC}"
        log "${RED}升级已中止，后续脚本未执行${NC}"
        exit 1
    fi
done

log "============================================================"
log "${GREEN}恭喜！所有数据库升级脚本执行完成！$(date '+%Y-%m-%d %H:%M:%S')${NC}"
log "============================================================"

exit 0