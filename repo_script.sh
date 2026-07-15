# 1. 設定路徑變數
repo_local_manifest=~/my_local_manifest_local
repo_folder=~/repo_GSN

# 2. 建立並初始化 Local Manifest Repo
mkdir -p "$repo_local_manifest"
cd "$repo_local_manifest"

git init

# 3. 寫入 default.xml 內容
cat << 'EOF' > default.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="origin" 
          fetch="https://quanta-bmc-private.googlesource.com/" 
          review="https://quanta-bmc-private-review.googlesource.com/" />
  
  <remote name="gbmc-private"   
          fetch="https://gbmc-private.googlesource.com/" 
          review="https://gbmc-private-review.googlesource.com/" />
  
  <remote name="gbmc-public"    
          fetch="https://gbmc.googlesource.com/" 
          review="https://gbmc-review.googlesource.com/" />

  <default revision="master" sync-j="12" />

  <project path="openbmc"
           remote="origin"
           name="openbmc"
           revision="google-dev" />

  <project path="openbmc/meta-google-private"
           remote="gbmc-private"
           name="meta-google-private" />

  <project path="openbmc/meta-gbmc-staging"
           remote="gbmc-public"
           name="meta-gbmc-staging" />

  <project path="openbmc/meta-google-private/meta-quanta-google"
           remote="gbmc-private"
           name="meta-quanta-google" />
</manifest>
EOF

# 4. 進行 Commit
git add default.xml
git commit -m "Initial manifest for openbmc - GSN project"

echo "Local manifest repository has been initialized."

# 5. 開始初始化真正的 Repo 工作目錄
mkdir -p "$repo_folder"
cd "$repo_folder"

# 使用 -u 指定剛才建立的本地路徑
repo init -u "$repo_local_manifest"

# 提示執行 sync
echo "Init done. Now running 'repo sync' to fetch the source code."
echo "repo syncing, please wait..."
repo sync
