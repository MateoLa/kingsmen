FROM ruby:2.6.6
LABEL maintainer "Mateo Laiño (mateo.laino@gmail.com)"


# Set build args
ARG GITHUB_TOKEN
ARG DATABASE_HOST
ARG DATABASE
ARG DATABASE_USER
ARG DATABASE_PASSWORD
ARG RAILS_MASTER_KEY
ARG RAILS_ENV
ARG CACHE_REDIS_URL
ARG JOB_REDIS_URL

# Setting env
ENV DATABASE_HOST $DATABASE_HOST
ENV DATABASE $DATABASE
ENV DATABASE_USER $DATABASE_USER
ENV DATABASE_PASSWORD $DATABASE_PASSWORD
ENV RAILS_MASTER_KEY $RAILS_MASTER_KEY
ENV RAILS_ENV $RAILS_ENV
ENV RAILS_SERVE_STATIC_FILES false
ENV CACHE_REDIS_URL $CACHE_REDIS_URL
ENV JOB_REDIS_URL $JOB_REDIS_URL

# Enable the Yarn repository
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && apt-get install -y \
    build-essential nodejs libpq-dev yarn git nano
RUN gem install bundler -v 2.1.4

# Set an environment variable where the Rails app is installed
ENV RAILS_ROOT /home/epa-market
RUN mkdir -p $RAILS_ROOT

# Set working directory
WORKDIR $RAILS_ROOT

# COPY Gemfile* ./
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock

# Set github token
RUN bundle config github.com $GITHUB_TOKEN
# Install ruby gems
RUN bundle install --without test
RUN bundle config --delete github.com

# Copy the main application.
COPY . $RAILS_ROOT

# Initialize application configuration & assets.
RUN yarn install --check-files

# RUN rake db:migrate
# RUN RAILS_ENV=production bundle exec rake assets:precompile

COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

EXPOSE 9000
