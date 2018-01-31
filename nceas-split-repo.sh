#!/bin/sh
WORKDIR=${PWD}

# Split a git repo into a historical and current halves at $TRUNCPOINT
# Following guidelines at https://git-scm.com/book/en/v2/Git-Tools-Replace

# For metacat, we want to split on TRUNCPOINT on Apr 25, 2013 at SHA b3f7c89c47084b6bb9e0c64fc55dbe8d6fc5cbf4
# For metacat, the parent of TRUNCPOINT is SHA f7f40cb91f7e9bcf181740cee36504ca3ea2a008
TRUNCPOINT='b3f7c89c47084b6bb9e0c64fc55dbe8d6fc5cbf4'
TRUNCPARENT="f7f40cb91f7e9bcf181740cee36504ca3ea2a008"
SOURCE="metacat-archive"
ORIG_REPO_NAME="metacat-split"
HIST_REPO_NAME="metacat-history"
NEW_REPO_NAME="metacat-recent"
HIST_REPO="file://${WORKDIR}/${HIST_REPO_NAME}"
NEW_REPO="file://${WORKDIR}/${NEW_REPO_NAME}"

main () {
    create_repos
    
    # Mark the HEAD as SVN_MIGRATION_POINT for future reference
    cd ${WORKDIR}/${ORIG_REPO_NAME}
    git tag SVN_MIGRATION_POINT
    
    # First create a branch for the historical commits
    git branch history $TRUNCPOINT
    
    # Now copy the history repo to the remote HIST_REPO repository
    git push project-history history:master
    
    # Copy all branches before the TRUNCPOINT to the history repository
    git log --before="2013-8-1" --oneline --decorate --simplify-by-decoration --branches --pretty="%D" | \
        grep -v "tag: " | xargs -I % sh -c 'git checkout %; git push project-history %'
    git checkout master

	# Push tags to history repo
    git log --before="2013-8-1" --oneline --decorate --simplify-by-decoration --tags --pretty="%D" | \
        awk '/^tag: / {print $2}'| xargs -I % sh -c 'git push project-history %'
    
    # Create a base commit for the newly truncated repository
    MESSAGE="Get history from historical repository at $HIST_REPO"
    BASECOMMIT=`echo $MESSAGE | git commit-tree ${TRUNCPARENT}^{tree}`
    echo "Created new BASECOMMIT with SHA ${BASECOMMIT}"
    
    # Split the repository by grafting the TRUNCPARENT onto BASECOMMIT
    echo "${TRUNCPOINT} ${BASECOMMIT}" > .git/info/grafts
    git filter-branch -- --all

    # Push the current rewritten master to the new repository
	git push project-recent master

    # Copy all branches after the TRUNCPOINT to the new repository
    git log --after="2013-8-1" --oneline --decorate --simplify-by-decoration --branches --pretty="%D" | \
        grep -v "tag: " | xargs -I % sh -c 'git checkout %; git push project-recent %'

	# Push tags to new repo for recent commits
    git log --after="2013-8-1" --oneline --decorate --simplify-by-decoration --tags --pretty="%D" | \
        awk '/^tag: / {print $2}'| xargs -I % sh -c 'git push project-recent %'
    
}

create_repos () {
    rm -rf ${ORIG_REPO_NAME} ${HIST_REPO_NAME} ${NEW_REPO_NAME}

    # Duplicate the source repo so we work from a copy
    cp -rp ${SOURCE} ${ORIG_REPO_NAME}

    # Create the repo to contain the historical commits
    mkdir ${WORKDIR}/${HIST_REPO_NAME}
    cd ${WORKDIR}/${HIST_REPO_NAME}
    git init --bare
    cd ${WORKDIR}/${ORIG_REPO_NAME}
    git remote add project-history $HIST_REPO

    # Create the repo to contain the recent commits
    mkdir ${WORKDIR}/${NEW_REPO_NAME}
    cd ${WORKDIR}/${NEW_REPO_NAME}
    git init --bare
    cd ${WORKDIR}/${ORIG_REPO_NAME}
    git remote add project-recent $NEW_REPO
}

main
