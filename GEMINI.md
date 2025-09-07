# Gemini C++ Project Interaction Guide

This document provides guidelines for interacting with this C++ project using Gemini.

## Project Overview

This is the Lethean blockchain project, a confidential blockchain platform. We are currently in the process of upgrading our encrypted blockchain to modern standards. This upgrade includes swapping our old chain tokens to the new chain. The project is built in C++ and uses CMake for its build system, with a convenient Makefile wrapper.

## Key Technologies

*   **C++:** The core language of the project.
*   **CMake:** Used for the build system.
*   **Make:** Provides a simplified interface for building and testing.
*   **Boost:** Used for various C++ utilities.
*   **OpenSSL:** Used for cryptographic functions.
*   **Qt:** Used for the GUI.

## How to Build

The project can be built on Linux, Windows, and macOS using the provided Makefile.

### 1. Prerequisites

Ensure you have the necessary prerequisites installed. For a Debian-based system, you can use the following command:

```bash
sudo apt-get install -y build-essential g++ curl autotools-dev libicu-dev libbz2-dev cmake git screen checkinstall zlib1g-dev libssl-dev bzip2
```

### 2. Build the Project

To build the project, you can use the `make dev-build` command. This will configure and build the project in release mode.

```bash
make dev-build
```

You can also build different configurations:
*   `make release`: Build the project in release mode.
*   `make debug`: Build the project in debug mode.
*   `make gui`: Build the project with the GUI.

## How to Run Tests

To run the tests, you can use the `make test` command. This will build the tests and then run them.

```bash
make test
```

## Code Style

This project uses `.clang-format` to enforce a consistent code style. Before submitting any code changes, please format your code using `clang-format`.

```bash
clang-format -i <file-to-format>
```

## Example Gemini Usage

Here are some examples of how you can use Gemini to interact with this project.

### Building the Project

To build the project, you can use the following prompt:

> **User:** Build the project using the `dev-build` target.

### Running Tests

To run the tests, you can use the following prompt:

> **User:** Run the tests using the `make test` command.

### Formatting Code

To format a file, you can use the following prompt:

> **User:** Format the file `src/main.cpp` using `clang-format`.

### Testing the Makefile/Cmake Build System

> **User:** Test the Makefile/CMake build system by running `make debug-configure` and checking its output.

### Adding a New Feature        

To add a new feature, you can follow these steps:

1.  **Create a new branch:**
    > **User:** Create a new git branch called `feature/my-new-feature`.
2.  **Modify the code:**
    > **User:** Open the file `src/some_file.cpp` and add my new feature.
3.  **Build the project:**
    > **User:** Build the project using `make dev-build` to make sure my changes didn't break anything.
4.  **Run the tests:**
    > **User:** Run the tests using `make test` to ensure my changes are working correctly.
5.  **Format the code:**
    > **User:** Format the files I changed using `clang-format`.
6.  **Commit the changes:**
    > **User:** Commit my changes with the message "Add my new feature".