#!/bin/bash

base_url="https://download.vmturbo.com/appliance/download/updates"
log_file="version_check.log"
max_attempts=100
my_ip_address=$(hostname -I | awk '{print $1}')
turbonomic_url="https://${my_ip_address}/vmturbo/rest/admin/versions"
checked_second_octet=false  # 追加: 第二オクテットを確認済みかどうか
best_version=""  # 追加: 見つかった最新のバージョン

# ログを出力する関数
log() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1" | tee -a "$log_file"
}

# バージョン番号をインクリメントする関数
increment_version() {
    local version=$1
    local arr=(${version//./ })

    if [ ${arr[2]} -lt 9 ]; then
        arr[2]=$((arr[2] + 1))
    else
        arr[2]=0
        arr[1]=$((arr[1] + 1))
    fi

    echo "${arr[0]}.${arr[1]}.${arr[2]}"
}

# jqがインストールされていない場合、インストールする関数
install_jq() {
    if ! command -v jq > /dev/null; then
        log "jqが見つかりません。インストールを開始します。"
        yum install -y epel-release
        yum install -y jq
        log "jqのインストールが完了しました。"
    else
        log "jqはすでにインストールされています。"
    fi
}

install_jq

# 現在のバージョンを取得
current_version=$(curl -k "${turbonomic_url}" | jq -r '.version')
log "現在のバージョン: ${current_version}"

attempt=0
latest_version=""

# onlineUpgrade.shファイルが存在するかどうかをチェックする関数
check_upgrade_file() {
    local url=$1
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$http_status" -eq 200 ]; then
        return 0  # ファイルが存在する
    else
        return 1  # ファイルが見つからない
    fi
}

# 最大試行回数までバージョンをチェック
while [ $attempt -lt $max_attempts ]; do
    current_version=$(increment_version "$current_version")
    download_url="${base_url}/${current_version}/onlineUpgrade.sh"

    # onlineUpgrade.shが存在するか確認
    if check_upgrade_file "$download_url"; then
        log "新しいバージョンが見つかりました: ${current_version}"
        latest_version="$current_version"

        # 最新バージョンが見つかった場合、必ずbest_versionを更新
        best_version="$current_version"
    else
        log "新しいバージョンが見つかりません: ${current_version}"

        # 第二オクテットをまだ確認していない場合、インクリメントしてチェック
        if [ "$checked_second_octet" = false ]; then
            log "第二オクテットの更新を確認します。"
            arr=(${current_version//./ })
            arr[2]=0
            arr[1]=$((arr[1] + 1))
            current_version="${arr[0]}.${arr[1]}.${arr[2]}"
            log "次のバージョンを確認します: ${current_version}"
            checked_second_octet=true  # 一度だけ第二オクテットを試す

            # 第二オクテットが更新された場合のバージョンをbest_versionに設定
            if check_upgrade_file "${base_url}/${current_version}/onlineUpgrade.sh"; then
                best_version="$current_version"
                log "新しい第二オクテットバージョンが見つかりました: ${best_version}"
            fi

            continue
        fi
        break
    fi

    attempt=$((attempt + 1))
done

# 最新のバージョン（best_version）をダウンロードして実行
if [ -n "$best_version" ]; then
    log "最も新しいバージョン: $best_version をダウンロードして実行します。"
    download_url="${base_url}/${best_version}/onlineUpgrade.sh"
    wget -O "onlineUpgrade-${best_version}.sh" "$download_url"
    log "ダウンロード完了: onlineUpgrade-${best_version}.sh"

    # ダウンロードしたファイルに実行権限を付与
    chmod +x "onlineUpgrade-${best_version}.sh"

    # "n"を選択して実行
    echo "n" | ./onlineUpgrade-${best_version}.sh "${best_version}"
    log "onlineUpgrade-${best_version}.shを実行しました。"
else
    log "新しいバージョンは見つかりませんでした。"
fi
