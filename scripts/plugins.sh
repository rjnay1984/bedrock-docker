declare DEPENDENCIES=(${DEPENDENCIES//,/ })
declare AUTO_UPDATE=${AUTO_UPDATE:-true}

update_dependencies() {
    cd /app/

    # Get base packages which are installed after 'composer create-project roots/bedrock'.
    base=$(cat composer.base |
        jq '.require' |
        jq --compact-output 'keys' |
        tr -d '[]"' | tr ',' '\n')

    # Get all currently installed packages including $base from above.
    current=$(cat composer.json |
        jq '.require' |
        jq --compact-output 'keys' |
        tr -d '[]"' | tr ',' '\n')

    # Exclude $base packages from $current packages.
    additional=($(comm -13 <(printf '%s\n' "${base[@]}" | LC_ALL=C sort) <(printf '%s\n' "${current[@]}" | LC_ALL=C sort)))

    # Get packages from $DEPENDENCIES env var which are not yet installed.
    require=($(comm -13 <(printf '%s\n' "${additional[@]}" | LC_ALL=C sort) <(printf '%s\n' "${DEPENDENCIES[@]}" | LC_ALL=C sort)))

    # Get packages which are installed but not listeed in $DEPENDENCIES var and therefore remove them in the next step.
    removable=($(comm -13 <(printf '%s\n' "${DEPENDENCIES[@]}" | LC_ALL=C sort) <(printf '%s\n' "${additional[@]}" | LC_ALL=C sort)))

    if [ ${#removable[*]} -gt 0 ]; then
        h2 "Remove packages."
        echo ${removable[*]}
        composer remove ${removable[*]}
    fi

    # Regex pattern to match VCS dependencies (Git repos)
    # external dependencies have to look like this pattern
    #   - [vendor/package-name:branch-name]https://url-to-the-git-repo.git
    #   - [vendor/package-name:version]/path/to/volume
    # If dependency is not registerd by composer
    regexHttp="(\[(.*?):(.*?)\])([http].*)"
    regexLocal="(\[(.*?):(.*?)\])([^http].*)"

    h2 'Start installing dependencies.'

    for package in "${require[@]}"; do

        if [[ $package =~ $regexHttp ]]; then
            name="${BASH_REMATCH[2]}"
            version="${BASH_REMATCH[3]}"
            url="${BASH_REMATCH[4]}"
            printf "Install \e[0;32mvcs composer package\e[0m: \e[0;36m${name} ${version}\e[0m\n"
            composer config repositories.${name} '{"type": "vcs", "url": "'${url}'", "no-api": true }'
            composer require --update-with-dependencies ${name}:${version}
        elif [[ $package =~ $regexLocal ]]; then
            name="${BASH_REMATCH[2]}"
            version="${BASH_REMATCH[3]}"
            url="${BASH_REMATCH[4]}"
            printf "Install \e[0;32mlocalcomposer package\e[0m: \e[0;36m${name} ${version}\e[0m\n"
            composer config repositories.${name} '{"type": "path", "url": "'${url}'", "options": {"symlink": true}}'
            composer require --update-with-dependencies ${name}:${version}
        else
            printf "Install \e[0;32mcomposer package\e[0m: \e[0;36m${package}\e[0m\n"
            composer require --update-with-dependencies ${package}
        fi

    done

    if $AUTO_UPDATE; then
        h2 'Updating outdated dependencies.'
        composer update
    else
        h2 'Skipping updates.'
    fi

    h2 '✅  All dependencies successfully installed.'
}
