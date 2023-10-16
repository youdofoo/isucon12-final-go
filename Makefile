####################
# 以下はサンプル
# alp の matching、アプリのビルド、設定ファイルのコピー等は状況に合わせて変えること
####################

# alp settings
NGINX_LOG=/var/log/nginx/access.log
MATCHING="/user/[0-9]+/gacha/draw/[0-9]+/[0-9]+,/user/[0-9]+/gacha/index,/user/[0-9]+/item,/user/[0-9]+/present/receive,/user/[0-9]+/card,/admin/user/[0-9]+,/user/[0-9]+/present/index/[0-9]+,/user/[0-9]+/reward,/user/[0-9]+/home"
FIELDS=count,2xx,3xx,4xx,5xx,method,uri,min,max,sum,avg,p99

# slow query settings
SQ_LOG=/var/log/mysql/mysql-slow.log


TIME=$(shell TZ=JST-9 date +"%H%M")
#### analysis
.PHONY: alp
alp:
	sudo alp ltsv --file ${NGINX_LOG} -m ${MATCHING} -o ${FIELDS} --sort sum --reverse | tee /tmp/alp-$(TIME).txt

.PHONY: alp-slack
alp-slack: alp
	sed -e '1i ```' -e '$$a ```' /tmp/alp-$(TIME).txt | notify_slack

.PHONY: pt
pt:
	sudo pt-query-digest ${SQ_LOG} | tee /tmp/pt-$(TIME).txt

.PHONY: pt-slack
pt-slack: pt
	notify_slack /tmp/pt-$(TIME).txt

.PHONY: pprof
pprof:
	go tool pprof -http=localhost:9999 http://localhost:6060/debug/pprof/profile


#### deploy
REPOSITORY ?= origin
B ?= main
.PHONY: deploy
deploy: git-pull reset-log deploy-app deploy-nginx deploy-mysql

.PHONY: git-pull
git-pull:
	git fetch && \
	git checkout $(B) && \
	git merge $(REPOSITORY)/$(B)

.PHONY: deploy-app
deploy-app:
	sudo systemctl daemon-reload && \
	sudo systemctl restart isuconquest.go.service

.PHONY: reset-log
reset-log:
	sudo bash -c 'echo "" > /var/log/nginx/access.log'
	sudo bash -c 'echo "" > /var/log/mysql/mysql-slow.log'
	sudo bash -c 'rm -rf /home/isucon/xhprof/out/ && mkdir -p /home/isucon/xhprof/out/ && chown isucon:isucon /home/isucon/xhprof/out/'

.PHONY: deploy-nginx
deploy-nginx:
	sudo systemctl restart nginx

.PHONY: deploy-mysql
deploy-mysql:
	sudo systemctl restart mysql