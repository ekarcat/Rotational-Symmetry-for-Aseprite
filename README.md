<img width="1010" height="667" alt="Animation" src="https://github.com/user-attachments/assets/43ac31e6-e9ca-41ae-b710-1409ff4ce08e" />

### Feature
- Implements rotational symmetry.

### Known Bug
<img width="1010" height="667" alt="Animation2" src="https://github.com/user-attachments/assets/593b6274-090d-4c43-ad5f-343005357e67" />
- This issue only occurs for pixels of the same color. When generating duplicates for the symmetrical drawing, the script assumes duplicates of the pixels drawn prior to script execution already exist, causing it to skip that specific area.

To bypass this, try either of the following:
1. Separate your workflow into asymmetric and symmetric layers.
2. Clear the asymmetric drawing before you begin.
