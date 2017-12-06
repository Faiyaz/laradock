###################################################
# Makefile variables
###################################################
BUILD = false
REMOVE = false
USER = laradock
ADMIN_PATH = ../admin
DATA_STORAGE_PATH = ../local-containers-data
LOCAL_YML = local-containers.yml
DAM_CONTAINERS = mysql nginx
LOCAL_DOCKER_COMPOSE = docker-compose -f $(LOCAL_YML)
WORKSPACE_BASH = $(LOCAL_DOCKER_COMPOSE) exec --user $(USER) workspace bash
WORKSPACE_ENTER_MESSAGE = $(call colorecho, '[ User $(USER) logged into workspace. ]', 1)
WORKSPACE_EXIT_MESSAGE = $(call colorecho, '[ User $(USER) logged out of workspace. ]', 1)
ROOT_ERROR_MESSAGE = $(call colorecho, 'Please do not run make as root or with sudo', 1)

###################################################
# Makefile targets
###################################################

# Initializes the project
# - Default target.
# - Dependends on docker_up, project_init
start: check_root docker_up project_init

# Do a complete fresh start
fresh_start: remove_local_data docker_down start

# Prevent file execution by root user or sudo
check_root:
ifeq ($(shell id -u),0)
	$(ROOT_ERROR_MESSAGE)
	@exit 1
endif

# If admin project exist, update it, otherwise clone it from remote repo. Once done,
admin:
	$(call colorecho, "Checking if project exist", 3)
ifneq (,$(wildcard $(ADMIN_PATH)))
	$(call colorecho, "Project exist", 2)
	$(call colorecho, "Updating git repository", 5)
	@cd $(ADMIN_PATH) && git fetch --all && git pull
else
	$(call colorecho, "Project does not exist", 1)
	$(call colorecho, "Cloning project", 5)
	@git clone git@bitbucket.org:connectedventures/admin.git $(ADMIN_PATH)
endif

# Copy env files if they don't exist
# - depends on admin
cp_envs: admin
ifeq (,$(wildcard $(ADMIN_PATH)/.env))
	@cp $(ADMIN_PATH)/env.example $(ADMIN_PATH)/.env
endif
ifeq (,$(wildcard $(ADMIN_PATH)/.env.dusk.local))
	@cp .env.admin.dusk.example $(ADMIN_PATH)/.env.dusk.local
endif

# Initialize the project.
# Composer install, generate project key, and symlink the storage directory from host machine.
# Run migration target.
project_init: cp_envs
	@cd $(ADMIN_PATH) && composer install && php artisan key:generate && php artisan storage:link
#	@$(MAKE) project_migration

# Project migration.
project_migration:
	$(call colorecho, "Starting migration process", 5)
	$(call workspace_cmd, "cd admin && php artisan migrate")

# Project migration.
project_seed:
	$(call colorecho, "Starting seeding process", 5)
	$(call workspace_cmd, "cd admin && php artisan db:seed")

# Remove all the local data
remove_local_data: docker_stop
	$(call colorecho, "Removing all data from local storage", 1)
	@rm -rfv $(DATA_STORAGE_PATH)/*

# Log into orkspace bash
# - By default, user 'laradock' will be used for logging in
workspace_login:
	$(call workspace_login)

###################################################
# Makefile dynamic targets
###################################################

# Map given docker commands from target -> function.
# - Use docker_up, docker_down, docker_start, docker_stop
docker_%:
	$(call colorecho,"Initiating $@",3)
	$(call $@)


###################################################
# Makefile PHONY targets
###################################################
.PHONY: project_init project_migration cp_envs workspace_login check_root

###################################################
# Makefile user functions
###################################################

# Bring up docker containers.
# - If BUILD is true, existing container will be re-built.
# - By default all container names will be used.
# - If container names are specified, only those containers will be brought up.
define docker_up
	@$(LOCAL_DOCKER_COMPOSE) up -d $(if $(filter $(BUILD),true),--build,) $(DAM_CONTAINERS)
endef

# Bring down docker containers.
# - If REMOVE is true, all image asscociated will be removed.
# - Containers that were orphaned due to modifications, will be removed.
define docker_down
	@$(LOCAL_DOCKER_COMPOSE) down --remove-orphans $(if $(filter $(REMOVE),true),--rmi=all,)
endef

# Stop containers.
# - By default, all asscociated containers will be stopped.
# - If container names are specified, only those containers will be stopped.
define docker_stop
	@$(LOCAL_DOCKER_COMPOSE) stop $(DAM_CONTAINERS)
endef

# Start containers
# - By default, all asscociated containers will be started.
# - If container names are specified, only those containers will be started
define docker_start
	@$(LOCAL_DOCKER_COMPOSE) start $(DAM_CONTAINERS)
endef

# Display the containers info
define docker_ps
	@$(LOCAL_DOCKER_COMPOSE) ps
endef

# Log into workspace
# - By default, user 'laradock' will be used to login to workspace.
define workspace_login
	$(WORKSPACE_ENTER_MESSAGE)
	@$(WORKSPACE_BASH);
endef

# Run given command(s) on workspace container and exit.
# - By default, user 'laradock' will be used to login to workspace.
define workspace_cmd
	$(WORKSPACE_ENTER_MESSAGE)
	@$(WORKSPACE_BASH) --login -c $(1); exit 0;
	$(WORKSPACE_EXIT_MESSAGE)
endef

# Print into terminal with choice of color [1-7].
# - Argument 1 is the string.
# - Argument 2 is the color option defined in tput.
define colorecho
      @tput setaf $2 && printf $(1)'\n' && tput sgr0
endef
