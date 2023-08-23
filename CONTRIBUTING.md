# Contributing

This document is based on ideas and guidelines from the [xarray
Contributing
Guide](http://xarray.pydata.org/en/stable/contributing.html), which in
turn builds largely upon the [Pandas Contributing
Guide](http://pandas.pydata.org/pandas-docs/stable/contributing.html) .
Some of the guidelines are more aspirational than practical at this
point and constitute an attempt to learn how to build a proper open
source software repository.
:::

# Where to start?

All contributions, bug reports, bug fixes, documentation improvements,
enhancements, and ideas are welcome.

If you are brand new to *perturb* or open-source development, we
recommend going through the [GitHub \"issues\"
tab](https://github.com/jessecusack/perturb/issues) to find issues that
interest you. There are a number of issues listed under
[Documentation](https://github.com/jessecusack/perturb/issues?q=is%3Aissue+is%3Aopen+label%3Adocumentation)
and [good first
issue](https://github.com/jessecusack/perturb/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22)
where you could start out. Once you\'ve found an interesting issue, you
can return here to get your development environment setup.

# Bug reports and enhancement requests

Bug reports are an important part of making *perturb* more stable.
Having a complete bug report will allow others to reproduce the bug and
provide insight into fixing. See [this stackoverflow
article](https://stackoverflow.com/help/mcve) for tips on writing a good
bug report.

Trying the bug-producing code out on the *main* branch is often a
worthwhile exercise to confirm the bug still exists. It is also worth
searching existing bug reports and pull requests to see if the issue has
already been reported and/or fixed.

Bug reports must:

1.  Include a short, self-contained matlab snippet reproducing the
    problem. You can format the code nicely by using [GitHub Flavored
    Markdown](http://github.github.com/github-flavored-markdown/):

        ```matlab
        process_VMP_files( ... )
        ```

2.  Explain why the current behavior is wrong/not desired and what you
    expect instead.

The issue will then show up to the *perturb* community and be open to
comments/ideas from others.

# Working with the code

Now that you have an issue you want to fix, enhancement to add, or
documentation to improve, you need to learn how to work with GitHub and
the *perturb* code base.

## Version control, Git, and GitHub

To the new user, working with Git is one of the more daunting aspects of
contributing to *perturb*. It can very quickly become overwhelming, but
sticking to the guidelines below will help keep the process
straightforward and mostly trouble free. As always, if you are having
difficulties please feel free to ask for help.

The code is hosted on
[GitHub](https://www.github.com/jessecusack/perturb). To contribute you
will need to sign up for a [free GitHub
account](https://github.com/signup/free). We use
[Git](http://git-scm.com/) for version control to allow many people to
work together on the project.

Some great resources for learning Git:

-   the [GitHub help pages](http://help.github.com/).
-   the [NumPy\'s
    documentation](http://docs.scipy.org/doc/numpy/dev/index.html).

## Getting started with Git

[GitHub has instructions](http://help.github.com/set-up-git-redirect)
for installing git, setting up your SSH key, and configuring git. All
these steps need to be completed before you can work seamlessly between
your local repository and GitHub.

## Forking

You will need your own fork to work on the code. Go to the [perturb
project page](https://github.com/jessecusack/perturb) and hit the `Fork`
button. You will want to clone your fork to your machine:

    git clone https://github.com/your-user-name/perturb.git
    cd perturb
    git remote add upstream https://github.com/jessecusack/perturb.git

This creates the directory `perturb/` and connects your
repository to the upstream (main project) *perturb* repository.

## Creating a branch

You want your main branch to reflect only production-ready code, so
create a feature branch for making your changes. For example:

    git branch shiny-new-feature
    git checkout shiny-new-feature

The above can be simplified to:

    git checkout -b shiny-new-feature

This changes your working directory to the shiny-new-feature branch.
Keep any changes in this branch specific to one bug or feature so it is
clear what the branch brings to *perturb*. You can have many
\"shiny-new-features\" and switch in between them using the
`git checkout` command.

To update this branch, you need to retrieve the changes from the main
branch:

    git fetch upstream
    git rebase upstream/main

This will replay your commits on top of the latest *perturb* git main.
If this leads to merge conflicts, you must resolve these before
submitting your pull request. If you have uncommitted changes, you will
need to `git stash` them prior to updating. This will effectively store
your changes and they can be reapplied after updating.

# Contributing to the documentation

If you\'re not the developer type, contributing to the documentation is
still of huge value. The documentation is written in markdown (indicated 
by files ending in `.md`), which is almost like writing in plain English. 

# Contributing your changes to *perturb*

## Committing your code

Once you\'ve made changes, you can see them by typing:

    git status

If you have created a new file, it is not being tracked by git. Add it
by typing:

    git add path/to/file-to-be-added.m

Doing \'git status\' again should give something like:

    # On branch shiny-new-feature
    #
    #       modified:   /relative/path/to/file-you-added.m
    #

The following defines how a commit message should be structured:

> -   A subject line with < 72 chars.
> -   One blank line.
> -   Optionally, a commit message body.

Please reference the relevant GitHub issues in your commit message using
`GH1234` or `#1234`. Either style is fine, but the former is generally
preferred.

Now you can commit your changes in your local repository:

    git commit -m

This will prompt you to type in your commit message.

## Pushing your changes

When you want your changes to appear publicly on your GitHub page, push
your forked feature branch\'s commits:

    git push origin shiny-new-feature

Here `origin` is the default name given to your remote repository on
GitHub. You can see the remote repositories:

    git remote -v

If you added the upstream repository as described above you will see
something like:

    origin      git@github.com:yourname/perturb.git (fetch)
    origin      git@github.com:yourname/perturb.git (push)
    upstream    git://github.com/jessecusack/perturb.git (fetch)
    upstream    git://github.com/jessecusack/perturb.git (push)

Now your code is on GitHub, but it is not yet a part of the *perturb*
project. For that to happen, a pull request needs to be submitted on
GitHub.

## Review your code

When you\'re ready to ask for a code review, file a pull request. Before
you do, once again make sure that you have followed all the guidelines
outlined in this document regarding code style, tests, and
documentation. You should also double check your branch changes against
the branch it was based on:

1.  Navigate to your repository on GitHub \--
    <https://github.com/your-user-name/perturb>
2.  Click on `Branches`
3.  Click on the `Compare` button for your feature branch
4.  Select the `base` and `compare` branches, if necessary. This will be
    `main` and `shiny-new-feature`, respectively.

## Finally, make the pull request

If everything looks good, you are ready to make a pull request. A pull
request is how code from a local repository becomes available to the
GitHub community and can be looked at and eventually merged into the
main version. This pull request and its associated changes will
eventually be committed to the main branch and available in the next
release. To submit a pull request:

1.  Navigate to your repository on GitHub
2.  Click on the `Pull Request` button
3.  You can then click on `Commits` and `Files Changed` to make sure
    everything looks okay one last time
4.  Write a description of your changes in the `Preview Discussion` tab
5.  Click `Send Pull Request`.

This request then goes to the repository maintainers, and they will
review the code. If you need to make more changes, you can make them in
your branch, add them to a new commit, push them to GitHub, and the pull
request will be automatically updated. Pushing them to GitHub again is
done by:

    git push origin shiny-new-feature

## Delete your merged branch (optional)

Once your feature branch is accepted into upstream, you\'ll probably
want to get rid of the branch. First, merge upstream main into your
branch so git knows it is safe to delete your branch:

    git fetch upstream
    git checkout main
    git merge upstream/main

Then you can do:

    git branch -d shiny-new-feature

Make sure you use a lower-case `-d`, or else git won\'t warn you if your
feature branch has not actually been merged.

The branch will still exist on GitHub, so to delete it there do:

    git push origin --delete shiny-new-feature
