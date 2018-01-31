#!/bin/bash
WORKDIR=${PWD}

create_repos () {
    rm -rf repo-split-example repo-split-recent repo-split-history
    # Create the repo to be split
    example_repo
    
    # Create the repo to contain the historical commits
    HISTREPO="file://${WORKDIR}/repo-split-history"
    mkdir ../repo-split-history
    cd ../repo-split-history/
    git init --bare
    cd ../repo-split-example
    git remote add project-history $HISTREPO

    # Create the repo to contain the recent commits
    RECEREPO="file://${WORKDIR}/repo-split-recent"
    mkdir ../repo-split-recent
    cd ../repo-split-recent/
    git init --bare
    cd ../repo-split-example
    git remote add project-recent $RECEREPO

}

example_repo () {
    # Part I: set up a test repo with our example commits
    mkdir repo-split-example
    cd repo-split-example/
    git init
    echo "We want to split the repository into project-recent and project-history portions, following the instructions at https://git-scm.com/book/en/v2/Git-Tools-Replace., but also including branches." > README.md
    echo " "
    echo "First commit." >> README.md
    git add README.md
    git commit -m "first"
    echo "Second commit." >> README.md
    git add README.md
    git commit -m "second"
    
    git checkout -b A HEAD
    echo "Add Branch A change." >> README.md
    git add README.md
    git commit -m "branchA a1"
    
    git checkout master
    echo "Third commit." >> README.md
    git add README.md
    git commit -m "third"
    TRUNCPARENT=`git rev-parse HEAD`

    echo "Fourth commit." >> README.md 
    git add README.md
    git commit -m "fourth"
    TRUNCPOINT=`git rev-parse HEAD`

    echo "Fifth commit." >> README.md
    git add README.md
    git commit -m "fifth"
    FIFTH=`git rev-parse HEAD`
    
    git checkout -b B HEAD
    echo "Add Branch B change. b1" >> README.md
    git add README.md
    git commit -m "branchB b1"
    B1=`git rev-parse HEAD`
    
    echo "Add Branch B change. b2" >> README.md
    git add README.md
    git commit -m "branchB b2"
    B2=`git rev-parse HEAD`
    
    git checkout master
    echo "Sixth commit." >> README.md
    git add README.md
    git commit -m "sixth"

    # Now we have a repo with the requisite structure, ready to be split
    git log --graph --all --oneline --decorate
}


split_repo () {
    # Part II: Split the git repo into historical and current halves at $TRUNCPOINT
    # Following guidelines at https://git-scm.com/book/en/v2/Git-Tools-Replace
    
    # First create a branch for the historical commits
    echo "Branching history at $TRUNCPOINT"
    git branch history $TRUNCPOINT
    git log --graph --oneline --decorate history A
    
    # Now copy the history repo to the remote HISTREPO repository
    git push project-history history:master
    git push project-history A
    # Question: how to get the list of all branches to be pushed to project-history?
    # Want all branches with a merge-base prior to TRUNCPOINT
    
    # Now to split the repo to get the recent history from TRUNCPOINT to HEAD of master
    # Create a base commit for the new new recent history
    MESSAGE="Get history from historical repository at $HISTREPO"
    BASECOMMIT=`echo $MESSAGE | git commit-tree ${TRUNCPARENT}^{tree}`
    
    # Split the repository by grafting the TRUNCPARENT onto BASECOMMIT
    echo "${TRUNCPOINT} ${BASECOMMIT}" > .git/info/grafts
    git filter-branch -- --all

    # Finally, push the current rewritten master and associated branches to a new repository
    git push project-recent master
    git push project-recent B
}


shallow_clone () {
    DEPTH=`git rev-list HEAD ^${TRUNCPOINT} --count`
    rm -rf shallow_clone
    git clone --depth=${DEPTH} --no-single-branch file:///Users/jones/development/git-svn-migrate/repo-split-example shallow-clone
    cd shallow-clone
    git checkout -b B origin/B
    git filter-branch -- --all
    git log --decorate --graph --oneline --branches
    # then push to the recent repo
}

create_repos
split_repo 
#shallow_clone
