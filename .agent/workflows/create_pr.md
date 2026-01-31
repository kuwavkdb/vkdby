---
description: Create a Pull Request with a properly formatted description
---

1. Create a file named `pr_description.md` in the `tmp` directory with the content of the PR description.
   Ensure the markdown formatting (headers, lists, newlines) is correct in this file.

2. Run the `gh pr create` command using the `--body-file` option to read the description from the file.
   
   ```bash
   gh pr create --title "<PR_TITLE>" --body-file tmp/pr_description.md
   ```

3. (Optional) Remove the `tmp/pr_description.md` file after the PR is created.
