#!/bin/bash

# PATH
PATH=/sbin:/usr/sbin:/bin:/usr/bin

######################################################
# (要定義)IP定義
######################################################
# 内部ネットワークとして許可する範囲
# LOCAL_NET="xxx.xxx.xxx.xxx/xx"
# 内部ネットワークとして許可する範囲
#ANY="0.0.0.0/0"
# 信頼可能ホスト(配列) 監視サーバIP等を記載
#ALLOW_HOSTS=(
#  "xxx.xxx.xxx.xxx"
#  "xxx.xxx.xxx.xxx"
#  "xxx.xxx.xxx.xxx"
#)
# 無条件破棄するホスト(配列)
#DENY_HOSTS=(
#  "xxx.xxx.xxx.xxx"
#  "xxx.xxx.xxx.xxx"
#  "xxx.xxx.xxx.xxx"
#)


######################################################
# (要定義)Port定義
######################################################
SSH=22
FTP=20,21
DNS=53
SMTP=25,465,587
POP3=110,995
IMAP=143,993
HTTP=80,443
IDENT=113
NTP=123
MYSQL=3306
NETBIOS=135,137,138,139,445
DHCP=67,68

#==================================================================================


######################################################
# 関数定義
######################################################

# ルール適用前の初期化
initialize(){
  iptables -F # テーブル初期化
  iptables -X # チェーン解除
  iptables -Z # パケットカウンタ・バイトカウンタをゼロリセット
  iptables -P INPUT ACCEPT # 設定のため一時ポリシー変更
  iptables -P FORWARD ACCEPT # 設定のため一時ポリシー変更
  iptables -P DROP ACCEPT # 設定のため一時ポリシー変更
}

# ルール適用後の反映処理
finalize(){
  /etc/init.d/iptables save &&
  /etc/init.d/iptables restart &&
  return 0
  return 1
}


##################################################################################
# iptablesの初期化
##################################################################################
initialize

##################################################################################
# 基本ポリシーの設定
##################################################################################

# INPUT,FORWARDはホワイトリスト方式で許可,OUTPUTは基本全て許可
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP


##################################################################################
# 信頼できるホストの許可
##################################################################################

# ループバックアドレスの許可
iptables -A INPUT -i lo -j ACCEPT

# ローカルネットワークの許可
if [ "$LOCAL_NET" ]
then
  iptables -A INPUT -p tcp -s $LOCAL_NET -j ACCEPT
fi

# 信頼可能ホストの許可
if [ "${ALLOW_HOST[@]}" ]
then
  for allow_host in ${ALLOW_HOSTS[@]}
  do
    iptables -A INPUT -p tcp -s $allow_host -j ACCEPT
  done
fi

##################################################################################
# 指定ホストからのアクセスを拒否
##################################################################################
if [ "${DENY_HOSTS[@]}" ]
then
  for host in ${DENY_HOSTS[@]}
  do
    iptables -A INPUT -s $ip -m limit --limit 1/s -j LOG --log-prefix "deny_hosts: "
    iptables -A INPUT -s $ip -j DROP
  done
fi

##################################################################################
# 確立済のパケット通信は全て許可
##################################################################################

# 確立済パケット
iptables -A INPUT -p tcp -m state --state ESTABLISHED,RELATED -j ACCEPT

# // ICMP通信(ping等)の許可
iptables -A INPUT -p icmp -j ACCEPT

# // 新規ssh接続の許可(5接続以上は10秒に1回のみ接続可能とする)
iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attach --set
iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attach --rcheck --seconds 60
iptables -A INPUT -p tcp --syn -m state --state NEW --dport=$SSH -m limit --limit 6/m --limit-burst 10 -j ACCEPT


##################################################################################
# 攻撃対策：StealthScan
##################################################################################
iptables -N STEALTH_SCAN
iptables -A STEALTH_SCAN -j LOG --log-prefix "stealth_scan_attack: "
iptables -A STEALTH_SCAN -j DROP
iptables -A INPUT -p tcp --tcp-flags SYN,ACK SYN,ACK -m state --state NEW -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j STEALTH_SCAN
iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j STEALTH_SCAN


##################################################################################
# 攻撃対策：フラグメントパケットによるポートスキャン、DOS攻撃
##################################################################################
iptables -A INPUT -f -j LOG --log-prefix "fragment_packet: "
iptables -A INPUT -f -j DROP


##################################################################################
# 攻撃対策：Ping of Death
##################################################################################
iptables -N PING_OF_DEATH
iptables -A PING_OF_DEATH -p icmp icmp --icmp-type echo-request \
    -m hashlimit \
    --hashlimit 1/s \
    --hashlimit-burst 10 \
    --hashlimit-htable-expire 300000 \
    --hashlimit-mode srcip \
    --hashlimit-name t_PING_OF_DEATH \
    -j RETURN
iptables -A PING_OF_DEATH -j LOG --log-prefix "ping_of_death_attack: "
iptables -A PING_OF_DEATH -j DROP
iptables -A INPUT -p icmp --icmp-type echo-request


##################################################################################
# 攻撃対策：SYN Flood Attack
##################################################################################
iptables -N SYN_FLOOD
iptables -A SYN_FLOOD -p tcp --syn \
    -m hashlimit
    --hashlimit 200/s
    --hashlimit-burst 3 \
    --hashlimit-htable-expire 300000 \
    --hashlimit-mode srcip \
    --hashlimit-name t_SYN_FLOOD \
    -j RETURN
iptables -A SYN_FLOOD -j LOG --log-prefix "syn_flood_attack: "
iptables -A SYN_FLOOD -j DROP
iptables -A INPUT -p tcp --syn -j SYN_FLOOD


##################################################################################
# 攻撃対策：HTTP Dos/DDos
##################################################################################
iptables -N HTTP_DOS
iptables -A HTTP_DOS -p tcp -m multiport --dports $HTTP \
    -m hashlimit
    --hashlimit 1/s
    --hashlimit-burst 100 \
    --hashlimit-htable-expire 300000 \
    --hashlimit-mode srcip \
    --hashlimit-name t_HTTP_DOS \
    -j RETURN
iptables -A HTTP_DOS -j LOG --log-prefix "http_dos_attack: "
iptables -A HTTP_DOS -j DROP
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j HTTP_DOS


##################################################################################
# 攻撃対策：IDENT port probe
##################################################################################
iptables -A INPUT -p tcp -m multiport --dports $IDENT -j REJECT --reject-with tcp-reset


##################################################################################
# 攻撃対策：SSH Brute force
##################################################################################
iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --set
iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ssh_brute_force: "
iptables -A INPUT -p tcp --syn -m multiport --dports $SSH -m recent --name ssh_attack --rcheck --seconds 60 --hitcount 5 -j REJECT --reject-with tcp-reset


##################################################################################
# 攻撃対策：FTP Brute force
##################################################################################
iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --set
iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m recent --name ftp_attack --rcheck --seconds 60 --hitcount 5 -j LOG --log-prefix "ftp_brute_force: "
iptables -A INPUT -p tcp --syn -m multiport --dports $FTP -m


##################################################################################
# 攻撃対策：ブロードキャスト、マルチキャスト宛のパケットの破棄
##################################################################################
iptables -A INPUT -d 192.168.1.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 192.168.1.255 -j DROP
iptables -A INPUT -d 255.255.255.255 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 255.255.255.255 -j DROP
iptables -A INPUT -d 224.0.0.1 -j LOG --log-prefix "drop_broadcast: "
iptables -A INPUT -d 224.0.0.1 -j DROP


##################################################################################
# 全ホストからの入力許可
##################################################################################

# ICMP
iptables -A INPUT -p icmp -j ACCEPT # ANY -> SELF

# HTTP,HTTPS
iptables -A INPUT -p tcp -m multiport --dports $HTTP -j ACCEPT

# HTTP,HTTPS
iptables -A INPUT -p tcp -m multiport --dports $SSH -j ACCEPT

# DNS
iptables -A INPUT -p tcp -m multiport --dports $DNS -j ACCEPT

# FTP
iptables -A INPUT -p tcp -m multiport --dports $FTP -j ACCEPT

# SMTP
iptables -A INPUT -p tcp -m multiport --dports $SMTP -j ACCEPT

# POP3
iptables -A INPUT -p tcp -m multiport --dports $POP3 -j ACCEPT

# IMAP
iptables -A INPUT -p tcp -m multiport --dports $IMAP -j ACCEPT


##################################################################################
# 全ホストからの入力許可
##################################################################################
iptables -A INPUT -j LOG --log-prefix "drop: "
iptables -A INPUT -j DROP


##################################################################################
# SSH締め出し回避策
##################################################################################
trap `finalize && exit 0`
echo "In 60 seconds iptables will be automatically reset."
echo "Don't forget to test new SSH connection!"
echo "If there is no problem then press Ctrl-C to finish."
sleep 60
echo "rollback..."
initialize
