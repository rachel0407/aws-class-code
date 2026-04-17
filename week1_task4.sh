#!/bin/sh
# ↑ Shebang：告訴系統用 /bin/sh 來執行這個腳本

# 使用方式： sh ./ec2_info.sh <instance-id>
# 範例： sh ./ec2_info.sh i-0123456789abcdef0

# ---------- 1. 檢查參數 ----------
# $# 代表「使用者傳入的參數數量」
# -ne 1 代表「不等於 1」
# 如果使用者沒有剛好傳 1 個參數（instance-id），就提示用法並離開
if [ $# -ne 1 ]; then
    echo "Usage: $0 <instance-id>"   # $0 是腳本本身的名稱
    exit 1                            # 以錯誤狀態碼 1 結束
fi

# ---------- 2. 把第一個參數（instance-id）存到變數 ----------
# $1 代表使用者傳進來的第一個參數
INSTANCE_ID="$1"

# ---------- 3. 呼叫 AWS CLI 取得這台 EC2 的資訊 ----------
# aws ec2 describe-instances：AWS 提供的查詢 EC2 指令
# --instance-ids：指定要查詢哪一台機器
# --query：用 JMESPath 語法只挑出我們要的 8 個欄位，避免回傳一大包 JSON
#   Reservations[0].Instances[0] 代表第一筆 Reservation 裡的第一台 Instance
#   中括號 [ ... ] 把 8 個欄位組成一個陣列
# --output text：輸出成「用 Tab 分隔的純文字」，方便後面 awk 拆解
# 2>/dev/null：把錯誤訊息丟掉（不要汙染畫面）
# $( ... )：把指令的輸出結果存進變數 DATA
DATA=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,LaunchTime,VpcId,SubnetId,PrivateIpAddress,PublicIpAddress]' \
    --output text 2>/dev/null)

# ---------- 4. 檢查是否成功取得資料 ----------
# -z 代表「字串是空的」
# 如果 DATA 是空的（可能是 instance-id 不存在、沒權限、憑證錯誤等），就報錯離開
if [ -z "$DATA" ]; then
    echo "Error: unable to retrieve information for instance $INSTANCE_ID"
    exit 1
fi

# ---------- 5. 用 awk 把 8 個欄位拆出來 ----------
# echo "$DATA" 把變數內容送給 awk
# | 是「管線」，把前一個指令的輸出當作下一個指令的輸入
# awk '{print $N}' 會印出第 N 個欄位（預設以空白/Tab 分隔）
INSTANCE_ID_OUT=$(echo "$DATA" | awk '{print $1}')   # 第 1 欄：Instance ID
INSTANCE_TYPE=$(echo "$DATA"   | awk '{print $2}')   # 第 2 欄：機型，例如 t3.micro
STATE=$(echo "$DATA"           | awk '{print $3}')   # 第 3 欄：狀態，例如 running
LAUNCH_TIME=$(echo "$DATA"     | awk '{print $4}')   # 第 4 欄：啟動時間
VPC_ID=$(echo "$DATA"          | awk '{print $5}')   # 第 5 欄：VPC ID
SUBNET_ID=$(echo "$DATA"       | awk '{print $6}')   # 第 6 欄：Subnet ID
PRIVATE_IP=$(echo "$DATA"      | awk '{print $7}')   # 第 7 欄：私有 IP
PUBLIC_IP=$(echo "$DATA"       | awk '{print $8}')   # 第 8 欄：公有 IP（可能沒有）

# ---------- 6. 處理沒有 Public IP 的情況 ----------
# 如果機器沒有公有 IP，AWS CLI 會回傳字串 "None"，把它換成比較友善的 "N/A"
[ "$PUBLIC_IP" = "None" ] && PUBLIC_IP="N/A"

# ---------- 7. 依照題目指定的格式輸出 ----------
echo "=== EC2 Information ==="
echo "Instance ID   : $INSTANCE_ID_OUT"
echo "Instance Type : $INSTANCE_TYPE"
echo "State         : $STATE"
echo "Launch Time   : $LAUNCH_TIME"
echo "VPC ID        : $VPC_ID"
echo "Subnet ID     : $SUBNET_ID"
echo "Private IP    : $PRIVATE_IP"
echo "Public IP     : $PUBLIC_IP"
