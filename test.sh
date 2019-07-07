docker-compose -f rails-zen/docker-compose.unit.yml exec -e CHROME_HOSTNAME=chrome -e TEST_HOST=rz -e RAILS_ENV=test rz rspec --tag ~js
