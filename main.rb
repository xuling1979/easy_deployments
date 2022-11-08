def source_paths
  [__dir__]
end

def ask_with_default(prompt, default)
  value = ask("#{prompt} [#{default}]")
  value.blank? ? default : value
end

def app_name_dasherized
  app_name.gsub('_', '-')
end

def registry
  @registry ||= ask_with_default("What is your registry username?", "kobaltz")
end

def domain
  @domain ||= ask_with_default("What is the domain name of your server?", "railsapp.dev")
end

registry
domain

rails_command "db:system:change --to=postgresql"
remove_file "config/database.yml"
template "config/database.yml.erb", "config/database.yml"

generate(:controller, 'welcome', 'index')
route "root to: 'welcome#index'"

template './docker_files/.dockerignore.erb', '.dockerignore'
template './docker_files/docker-compose.yml.erb', 'docker-compose.yml'
template './docker_files/Dockerfile.dev.erb', 'Dockerfile.dev'
template './docker_files/docker-compose-prod.yml.erb', 'docker-compose-prod.yml'
template './docker_files/Dockerfile.prod.erb', 'Dockerfile.prod'

template './bin/deploy.erb', 'bin/deploy'
template './bin/entrypoint.sh.erb', 'bin/entrypoint.sh'

after_bundle do
  run 'bundle lock --add-platform aarch64-linux'
  run 'bundle lock --add-platform x86_64-darwin-19'
  run 'bundle lock --add-platform x86_64-linux'

  remove_file 'bin/dev'
  template './bin/dev.erb', 'bin/dev'

  run 'chmod +x ./bin/dev'
  run 'chmod +x ./bin/deploy'
  run 'chmod +x ./bin/entrypoint.sh'

  remove_file 'Procfile.dev'

  run 'docker compose run app bundle install'
  run 'docker compose run app yarn install'
  run 'docker compose run app bin/rails bin/rails db:create db:migrate db:seed'
  run 'docker compose down'

  git :init
  git add: '.'
  git commit: %( -m 'base' )
end

