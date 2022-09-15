FROM ruby:alpine3.13

ARG UID

# コンテナ側で生成されたファイルがroot権限で作成されたりするとlocal側での取り扱いがめんどくさい。（sudoしないとファイルを削除できなかったり）
# ローカル側のUID, GIDとコンテナ側でのUID, GIDを揃えられるようにDockerfileやdocker-composeを用意しておくと、このあたりがスムーズに行くようになる。
RUN adduser -D app -u ${UID:-1000}

RUN apk update \
      && apk add --no-cache gcc make libc-dev g++ mariadb-dev tzdata nodejs~=14 yarn

# 環境変数の設定(本番)
ENV RAILS_ENV=production

WORKDIR /myapp
COPY Gemfile .
COPY Gemfile.lock .

RUN bundle install

# シーエイチオウン、ファイルの所有者を変更するコマンド。
# COPY . /myapp 権限はroot:root なので変更
COPY --chown=app:app . /myapp

# yarn installをすることで、package.jsonから/node_modulesを作成しています。
RUN yarn install

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]
# docker-compose で起動しているから不要？
# EXPOSE 3000
# CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]


RUN chmod +x ./bin/webpack
RUN NODE_ENV=production ./bin/webpack

# rootユーザーに変更 (本番ではファイル編集をしない)
# USER app

RUN mkdir -p tmp/sockets
RUN mkdir -p tmp/pids

# volumeの追加 (FargateでNginxにボリュームを共有するため)
VOLUME /myapp/public
VOLUME /myapp/tmp

CMD /bin/sh -c "rm -f tmp/pids/server.pid && bundle exec puma -C config/puma.rb"
