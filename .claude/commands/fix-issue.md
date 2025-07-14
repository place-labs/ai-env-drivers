Fix the GitHub issue: $ARGUMENTS.

Note:: all issues are related to the `./drivers` repository. (you'll need to run git commands from this folder)

Please analyze and follow these steps:

# PLAN

1. Use 'gh issue view' to get the issue details
2. Understand the problem described in the issue.
3. Ask clarifying questions if necessary.
4. Understand the prior art for this issue
  - Search scratchpads for previous thoughts related to the issue
  - Search PRs to see if you can find history on this issue
  - Check the ChangeLog for history on this issue
  - Search the codebase for relevant files
5. Think harder about how to break the issue down into a series of small, managable tasks.
6. Document your plan
  - include the issue name in the filename
  - include a link to the issue in the scratchpad.

# CREATE

- Create a new branch in the drivers repository for the issue
- Ensure you properly reference the original issue in the branch name, commits and pull requests to ensure visibilty of work.
- Solve the issue in small, managable steps, according to your plan.
- Commit your changes after each step.

# TEST

- Write tests to describe the expected behaviour of your code
- If the tests are failing, fix them
- consider timeouts a failure
