#!/bin/sh

REPO=$1
LOCAL=$2

echo $REPO
echo $LOCAL

# Clone the repository to local using git svn
git svn clone $REPO --authors-file=author-transform.txt --no-metadata --prefix "" -s $LOCAL
cd $LOCAL

# clean up the branches and tags
# First check for duplicate tag and branch names: grep -v tags ../morpho-branches | xargs -I {} grep {} ../morpho-tags
# For any duplicates handle them individually
for t in $(git for-each-ref --format='%(refname:short)' refs/remotes/tags); do git tag ${t/tags\//} $t && git branch -D -r $t; done
for b in $(git for-each-ref --format='%(refname:short)' refs/remotes); do git branch $b refs/remotes/$b && git branch -D -r $b; done
for p in $(git for-each-ref --format='%(refname:short)' | grep @); do git branch -D $p; done
git branch -d trunk

#git remote add origin git@github.com:NCEAS/${LOCAL}.git

# Check if the latest commit is master, and if not, merge it; 
# commented out because this is a manual step that will vary by repository
# git merge UTILITIES_2_0_0

# Now clean up and push; commented out to be careful to do this manually
#git tag SVN_MIGRATION_POINT
#git push --help
#git push --all -u origin
#git push --tags origin
cd ..
