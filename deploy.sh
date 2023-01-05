# delete .deploy_git, public and remote blog folders
rm -rf .deploy_git
hexo clean
echo -ne '\n' | ssh root@sundocker.online rm -rf /usr/local/nginx/www/blog/*

# make public
hexo generate

# make .deploy_git
mkdir .deploy_git
# shellcheck disable=SC2164
cd .deploy_git
git init
# shellcheck disable=SC2103
cd ..
cp -r source/.github .deploy_git/

# deploy
hexo deploy
scp -r public/* root@sundocker.online:/usr/local/nginx/www/blog/
