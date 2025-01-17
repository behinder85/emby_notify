#!/bin/sh

BASE_ROOT=$(cd "$(dirname "$0")";pwd)
TOOLS_DIR=${BASE_ROOT}/tools
cd ${BASE_ROOT}
. ./user.conf


TITLE="$1"
DIGE="$2"
PIC_URL="$4"

function urlencode() {
   if [ ! $? -eq 0 ]; then echo -E "$1";return; fi
   encode_str=$(echo -E "$1" |sed "s/%/%%/g")
   printf -- "$encode_str" | "${TOOLS_DIR}"/curl -Gso /dev/null -w %{url_effective} --data-urlencode @- "" |cut -c 3-
}

BARK_TITLE=$(echo $(urlencode ${TITLE}))
BARK_DIGE=$(echo $(urlencode ${DIGE}))




function qywx()
{

    # RET=$("${TOOLS_DIR}"/curl -s https://qyapi.weixin.qq.com/cgi-bin/gettoken?"corpid="${CORPID}"&corpsecret="${CORP_SECRET}"")
    WECHAT_URL="${WECHAT_PROXY}/cgi-bin/gettoken?corpid=${CORPID}&corpsecret=${CORP_SECRET}"
    RET=$("${TOOLS_DIR}"/curl -s "${WECHAT_URL}")
    KEY=$(echo ${RET} | "${TOOLS_DIR}"/jq -r .access_token)

    

    cat>tmp_qywx<<EOF
{
   "touser" : "${TOUSER}",
   "msgtype" : "news",
   "agentid" : "${AGENTID}",
   "news" : {
       "articles":[
           {
               "title": "${TITLE}",
               "description": "${DIGE}",
               "picurl": "${PIC_URL}"
            }
       ]
   },
   "enable_id_trans": 0,
   "enable_duplicate_check": 0,
   "duplicate_check_interval": 1800
}
EOF

    # "${TOOLS_DIR}"/curl -d @tmp_qywx -XPOST https://qyapi.weixin.qq.com/cgi-bin/message/send?access_token="${KEY}"
    NOTIFY_URL="${WECHAT_PROXY}/cgi-bin/message/send?access_token=${KEY}"
    "${TOOLS_DIR}"/curl -d @tmp_qywx -XPOST "${NOTIFY_URL}"
    echo ""
    echo "删除临时文件"
    rm ${BASE_ROOT}/tmp_qywx
}

function pushplus()
{
    echo "token:" "${PUSHPLUS_TOKEN}"
    cat>tmp_pushplus<<EOF
{
    "token": "${PUSHPLUS_TOKEN}",
    "title": "${TITLE}",
    "content": "${CONTENT}",
    "template": "html",
    "topic": "${PUSHPLUS_GROUP}",
    "channel": "${PUSHPLUS_CHANNEL}"
}
EOF

    echo $(cat tmp_pushplus)
    "${TOOLS_DIR}"/curl --location --request POST 'http://www.pushplus.plus/send' \
    -H 'Content-Type: application/json' \
    -d @tmp_pushplus
    
    rm ${BASE_ROOT}/tmp_pushplus
}

function bark()
{
    BARK_URL="${BARK_PUSH_URL}/${BARK_KEY}/${BARK_TITLE}/${BARK_DIGE}"
    "${TOOLS_DIR}"/curl --location --request GET "${BARK_URL}"
}

function telegram()
{
    TG_URL='https://api.telegram.org/bot'${TG_TOKEN}'/sendMessage'
    cat>tmp_tg<<EOF
{
    "chat_id": "${TG_CHAT_ID}",
    "text": "${TITLE}\n\n${DIGE}\n${PIC_URL}"
}
EOF
    "${TOOLS_DIR}"/curl --location --request POST ${TG_URL} --header 'Content-Type: application/json' -d @tmp_tg
    echo ""
    echo "删除临时文件"
    rm ${BASE_ROOT}/tmp_tg
}


if [ ! -n "${CORP_SECRET}" ]; then
    echo "未配置企业微信参数或者配置不全，跳过通知！"
else
    qywx
fi

if [ ! -n "${PUSHPLUS_TOKEN}" ]; then
    echo "未配置pushplus参数，跳过通知！"
else
    pushplus
fi

if [ ! -n "${BARK_KEY}" ]; then
    echo "未配置Bark参数，跳过通知！"
else
    bark
fi

if [ ! -n "${TG_TOKEN}" ]; then
    echo "未配置电报参数或者配置不全，跳过通知！"
else
    telegram
fi
