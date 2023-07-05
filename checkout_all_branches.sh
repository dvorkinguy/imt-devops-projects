#!/bin/bash

for branch in $(git branch -a | grep remotes/origin | grep -v HEAD | sed 's/remotes\/origin\///'); do
    git checkout "$branch"
done
