Start-WARACollector -TenantID "2a10cbe7-4328-4b70-9eb2-d6563b13618d" -SubscriptionIds @("/subscriptions/aeb9757d-ccb5-46d1-8ee3-16d9ffba789c","/subscriptions/60fdee14-6285-4b72-9c42-de65cebd726e","/subscriptions/f1375ccc-1746-497f-8e15-c8f536baf6f4","/subscriptions/eeee99a3-5b6f-47ea-9726-c22a3137f17e","/subscriptions/25608b3d-7c0a-44c8-89a1-f1f9b58b1945") -RecommendationDataUri https://aka.ms/waraja/recommendations.json

Start-WARAAnalyzer -JSONFile 'WARA-File-2026-06-22-11-48.json' -RecommendationDataUri https://aka.ms/waraja/recommendations.json



# 特定のサブスクリプションを指定（パターン2と同じ）
$targetSubs = "'aeb9757d-ccb5-46d1-8ee3-16d9ffba789c', '60fdee14-6285-4b72-9c42-de65cebd726e', 'f1375ccc-1746-497f-8e15-c8f536baf6f4', 'eeee99a3-5b6f-47ea-9726-c22a3137f17e', '25608b3d-7c0a-44c8-89a1-f1f9b58b1945'"
$query = "Resources | where subscriptionId in ($targetSubs) | summarize Count=count() by type | order by Count desc"

# データを取得して PowerShell で画像通りのフォーマットに整形
az graph query -q $query --query "data" | ConvertFrom-Json | ForEach-Object {
    "•  $($_.type) ($($_.Count))"
}



# 1. 調査対象にしたいサブスクリプションID、またはサブスクリプション名を配列で指定
# ※ ここにご自身のサブスクリプション情報をコンマ区切りで必要な分だけ並べてください。
$targetSubscriptions = @(
    "aeb9757d-ccb5-46d1-8ee3-16d9ffba789c",
    "60fdee14-6285-4b72-9c42-de65cebd726e",
    "f1375ccc-1746-497f-8e15-c8f536baf6f4",
    "eeee99a3-5b6f-47ea-9726-c22a3137f17e",
    "25608b3d-7c0a-44c8-89a1-f1f9b58b1945"
)

# 現在アクティブなサブスクリプションを後で元に戻すために記憶
$originalSub = (az account show | ConvertFrom-Json).id
$report = @()

# 2. 指定されたサブスクリプションを順番にループ処理
foreach ($sub in $targetSubscriptions) {
    Write-Host "サブスクリプションを切り替え中: $sub ..." -ForegroundColor Cyan
    
    # 対象のサブスクリプションにコンテキストを切り替え
    az account set --subscription $sub | Out-Null
    
    # サブスクリプション内のすべての VM 情報を取得
    $vms = az vm list --query "[].{name:name, rg:resourceGroup, zones:zones, osDiskId:storageProfile.osDisk.managedDisk.id}" --output json | ConvertFrom-Json
    
    if (-not $vms) {
        Write-Host "  -> このサブスクリプションにはVMが見つかりませんでした。" -ForegroundColor Yellow
        continue
    }

    # 各 VM のゾーンと OS ディスクのゾーンをチェック
    foreach ($vm in $vms) {
        $vmZone = if ($vm.zones) { $vm.zones[0] } else { "None" }
        
        # ディスクの詳細情報を取得
        $diskInfo = az resource show --ids $vm.osDiskId --query "{name:name, zones:zones}" --output json | ConvertFrom-Json
        $diskZone = if ($diskInfo.zones) { $diskInfo.zones[0] } else { "None" }
        
        # ゾーンが一致しているか判定
        $status = if ($vmZone -eq $diskZone) { "OK" } else { "Mismatch" }
        
        # 結果をオブジェクトに追加
        $report += [PSCustomObject]@{
            "Subscription"  = $sub
            "VM Name"       = $vm.name
            "ResourceGroup" = $vm.rg
            "VM Zone"       = $vmZone
            "Disk Zone"     = $diskZone
            "Status"        = $status
        }
    }
}

# 3. 元々アクティブだったサブスクリプションに設定を戻す
az account set --subscription $originalSub | Out-Null
Write-Host "元のサブスクリプションに設定を戻しました。" -ForegroundColor Green

# 4. すべてのサブスクリプションから集まった結果を綺麗なテーブル形式で画面に表示
Write-Host "`n【監査結果一覧】" -ForegroundColor White
$report | Format-Table -AutoSize





& "$AzCopyExe" copy "C:\temp\pic2.png" "https://demoyunas.blob.core.windows.net/installer/ApexOne/pic2.png"

//------------------------------

# AzCopy のパス取得
$AzCopyRoot = "C:\Tools\AzCopy"

$AzCopyExe = Get-ChildItem `
  -Path $AzCopyRoot `
  -Recurse `
  -Filter "azcopy.exe" `
  -File |
  Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($AzCopyExe)) {
    throw "azcopy.exe が見つかりません。C:\Tools\AzCopy 配下を確認してください。"
}

# AzCopy バージョン確認
& "$AzCopyExe" --version

# ダウンロード先フォルダ作成
$DownloadDir = "C:\Tools"
New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null

# Storage / Blob 情報
$StorageAccount = "demoyunas"
$Container = "installer"

$SourceUrl = "https://$StorageAccount.blob.core.windows.net/$Container/ApexOne/pic2.png"
$DestinationFile = "$DownloadDir\pic2.png"

# ログイン状態確認
& "$AzCopyExe" login status

# ダウンロード実行
& "$AzCopyExe" copy "$SourceUrl" "$DestinationFile"

# ダウンロード結果確認
Get-ChildItem "$DownloadDir\pic2.png"

# ハッシュ確認
Get-FileHash "$DownloadDir\pic2.png" -Algorithm SHA256


//------------------------------
# AzCopy Upload
# パラメーター設定
$AzCopyRoot = "C:\Tools\AzCopy"
$StorageAccount = "demoyunas"
$Container = "installer"
$SourceFileName = "python-3.12.8-amd64.exe"
$SourceFilePath = "C:\temp\"
$DestUrl = "https://$StorageAccount.blob.core.windows.net/$Container/ApexOne/$SourceFileName"

# AzCopy.exe のパスを取得
$AzCopyExe = Get-ChildItem `
-Path $AzCopyRoot `
-Recurse `
-Filter "azcopy.exe" `
-File |
Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($AzCopyExe)) {
throw "azcopy.exe が見つかりません。C:\Tools\AzCopy 配下を確認してください。"
}

# AzCopy バージョン確認

& "$AzCopyExe" --version
$SourceFile = "$SourceFilePath$SourceFileName"
& "$AzCopyExe" copy "$SourceFile" "$DestUrl"
