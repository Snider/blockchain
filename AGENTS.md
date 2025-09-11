## 🤖 Gemini C++ Project Interaction Guide

This guide helps you interact with the C++ project using commands and prompts. The project uses **CMake** and a **Makefile** wrapper to manage builds, and the code follows a consistent style enforced by **`.clang-format`**.

---

### **Key Commands**

These are the primary commands you'll need to interact with the project:

| Command | Description |
| :--- | :--- |
| `make build_sdk` | Prepares the necessary libraries. |
| `make build` | Compiles the software. |
| `make test` | Builds and runs the tests. |
| `make clean-build`| Cleans the build directory. |

---

### **Prompts for Gemini**

You can use these simple prompts to get started. Just remember that **Gemini doesn't have branching ability** and **can't suggest changes** yet. It will get testing PR's and suggesting working changes later.

* **Build:**
    * `"Prep the libraries."` or `"Build the SDK."`
    * `"Compile the software."` or `"Build the project."`
* **Test:**
    * `"Run the tests."` or `"Test the project."`
* **Clean:**
    * `"Clean the build directory."` or `"Clean the project."`
* **Code Style:**
    * `"Format the file 'src/main.cpp' using clang-format."`