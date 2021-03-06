function get_current_action () {
    local info="$(git rev-parse --git-dir 2>/dev/null)"
    if [ -n "$info" ]; then
        local action
        if [ -f "$info/rebase-merge/interactive" ]
        then
            action=${is_rebasing_interactively:-"rebase -i"}
        elif [ -d "$info/rebase-merge" ]
        then
            action=${is_rebasing_merge:-"rebase -m"}
        else
            if [ -d "$info/rebase-apply" ]
            then
                if [ -f "$info/rebase-apply/rebasing" ]
                then
                    action=${is_rebasing:-"rebase"}
                elif [ -f "$info/rebase-apply/applying" ]
                then
                    action=${is_applying_mailbox_patches:-"am"}
                else
                    action=${is_rebasing_mailbox_patches:-"am/rebase"}
                fi
            elif [ -f "$info/MERGE_HEAD" ]
            then
                action=${is_merging:-"merge"}
            elif [ -f "$info/CHERRY_PICK_HEAD" ]
            then
                action=${is_cherry_picking:-"cherry-pick"}
            elif [ -f "$info/BISECT_LOG" ]
            then
                action=${is_bisecting:-"bisect"}
            fi
        fi

        if [[ -n $action ]]; then printf "%s" "${1-}$action${2-}"; fi
    fi
}

function build_prompt {
    local enabled=`git config --local --get oh-my-git.enabled`
    if [[ ${enabled} == false ]]; then
        echo "${PSORG}"
        exit;
    fi

    local prompt=""
    local grep=`sh -c 'which grep'`

    # Git info
    local current_commit_hash=$(git rev-parse HEAD 2> /dev/null)
    if [[ -n $current_commit_hash ]]; then local is_a_git_repo=true; fi

    if [[ $is_a_git_repo == true ]]; then
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
        if [[ $current_branch == 'HEAD' ]]; then local detached=true; fi

        local number_of_logs="$(git log --pretty=oneline -n1 2> /dev/null | wc -l)"
        if [[ $number_of_logs -eq 0 ]]; then
            local just_init=true
        else
            local upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)
            if [[ -n "${upstream}" && "${upstream}" != "@{upstream}" ]]; then local has_upstream=true; fi

            local git_status="$(git status --porcelain 2> /dev/null)"
            local action="$(get_current_action)"

            local number_of_untracked_modifications=$($grep -c "^.M " <<< "$git_status")
            local number_of_untracked_deletions=$($grep -c "^.D " <<< "$git_status")
            local number_of_untracked_adds=$($grep -c "^?? " <<< "$git_status")
            local number_of_untracked_changes=$(($number_of_untracked_modifications + $number_of_untracked_deletions + $number_of_untracked_adds))

            local number_of_cached_modifications=$($grep -c "^M " <<< "$git_status")
            local number_of_cached_adds=$($grep -c "^A " <<< "$git_status")
            local number_of_cached_deletions=$($grep -c "^D " <<< "$git_status")
            local number_of_cached_changes=$(($number_of_cached_modifications + $number_of_cached_adds + $number_of_cached_deletions))

            if [[ $number_of_untracked_changes -eq 0 && $number_of_cached_changes -gt 0 ]]; then local ready_to_commit=true; fi

            local tag_at_current_commit=$(git describe --exact-match --tags $current_commit_hash 2> /dev/null)
            if [[ -n $tag_at_current_commit ]]; then local is_on_a_tag=true; fi

            if [[ $has_upstream == true ]]; then
                local commits_diff="$(git log --pretty=oneline --topo-order --left-right ${current_commit_hash}...${upstream} 2> /dev/null)"
                local commits_ahead=$($grep -c "^<" <<< "$commits_diff")
                local commits_behind=$($grep -c "^>" <<< "$commits_diff")
            fi

            if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then local has_diverged=true; fi
            if [[ $has_diverged == false && $commits_ahead -gt 0 ]]; then local should_push=true; fi

            local will_rebase=$(git config --get branch.${current_branch}.rebase 2> /dev/null)

            if [[ -f ${GIT_DIR:-.git}/refs/stash ]]; then
                local number_of_stashes="$(wc -l 2> /dev/null < ${GIT_DIR:-.git}/refs/stash)"
            else
                local number_of_stashes=0
            fi
        fi
    fi

    echo "$(custom_build_prompt ${enabled:-true} ${current_commit_hash:-""} ${is_a_git_repo:-false} ${current_branch:-""} ${detached:-false} ${just_init:-false} ${has_upstream:-false} \
        ${number_of_untracked_modifications:-0} ${number_of_cached_modifications:-0} ${number_of_cached_adds:-0} ${number_of_untracked_deletions:-0} ${number_of_cached_deletions:-0} ${number_of_untracked_adds:-0} \
        ${ready_to_commit:-false} ${tag_at_current_commit:-""} ${is_on_a_tag:-false} ${has_upstream:-false} ${commits_ahead:-false} ${commits_behind:-false} ${has_diverged:-false} ${should_push:-false} ${will_rebase:-false} ${number_of_stashes:-false} ${action})"

}
