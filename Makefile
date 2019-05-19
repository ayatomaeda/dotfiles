.PHONY: help
help: ## Display this help screen
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
.DEFAULT_GOAL := help

install: download brew deploy ## Install & Deploy

clean: undeploy unbrew remove ## Remove all libraries and dotfiles

.PHONY: download
download: ## Download libraries
	# color scheme
	git clone https://github.com/altercation/solarized.git ./etc/lib/solarized
	git clone https://github.com/seebi/dircolors-solarized.git ./etc/lib/dircolors-solarized
	# font: source-han-code-jp
	git clone https://github.com/adobe-fonts/source-han-code-jp.git ./etc/lib/source-han-code-jp

.PHONY: remove
remove: ## Remove downloaded libraries
	rm -rf ${PWD}/etc/lib/solarized 
	rm -rf ${PWD}/etc/lib/dircolors-solarized 
	rm -rf ${PWD}/etc/lib/source-han-code-jp

.PHONY: brew
brew: ## Install package
	brew install coreutils

.PHONY: unbrew
unbrew: ## Uninstall package
	brew uninstall coreutils

.PHONY: deploy
deploy: ## Deploy dotfiles
	ln -s ${PWD}/.bash_profile ${HOME}/.bash_profile
	ln -fs ${PWD}/etc/lib/dircolors-solarized/dircolors.ansi-universal ${HOME}/.dircolors-solarized
	
.PHONY: undeploy
undeploy: ## Undeploy dotfiles
	unlink ${HOME}/.bash_profile
	unlink ${HOME}/.dircolors-solarized



