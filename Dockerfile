FROM ruby:2.6
RUN apt-get update -qq && apt-get install -y build-essential opencc libopencc-dev
RUN mkdir /app
WORKDIR /app
COPY Gemfile /app/Gemfile
COPY Gemfile.lock /app/Gemfile.lock
RUN bundle install
COPY . /app
RUN ruby build.rb
ENTRYPOINT [ "ruby", "./main.rb"]
