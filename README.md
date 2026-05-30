# Vikunja Client for Sailfish OS

A native, high-performance task manager and note-taking client for **Sailfish OS** communicating with your self-hosted or cloud-hosted **Vikunja** instance.

Built with **C++**, **Qt5**, and **Silica QML** components, this application offers a fluid, premium mobile experience tailored specifically to the Sailfish OS ecosystem.

---

## About Vikunja

Vikunja is an open-source, feature-rich to-do list application that allows you to organize your tasks, notes, lists, and projects elegantly.

*   Project Website: [https://vikunja.io](https://vikunja.io)
*   Developer API Docs: [https://vikunja.io/docs/api](https://vikunja.io/docs/api)

---

## Features

*   **Setup/Login Screen**: Connect securely to your personal server using a custom domain and your API token.
*   **Projects & Lists Overview**: Seamlessly load projects/lists from the server.
*   **Task List Dashboard**: View all active and completed tasks in a beautiful interactive scrolling list.
*   **Detailed Task View**: Inspect task titles, detailed descriptions, and due dates in an elegant UI.
*   **Actionable Silica Delegates**: Toggle completion status or delete tasks instantly using swipe gestures or Silica's native ContextMenu actions.
*   **Dialog Creator**: Easily add new tasks or edit existing ones using standard datepicker widgets.

---

## Setup & Compilation

The project uses the standard Sailfish SDK shadow build layout. Sourcing the local `.envrc` activates the `SailfishOS-4.6.0.13-armv7hl` target.

### Standard Build Suite
1.  **Configure**:
    ```bash
    sfdk qmake ../harbour-vikunja/harbour-vikunja.pro
    ```
2.  **Compile & Deploy**:
    ```bash
    sfdk make-install
    ```
3.  **Package**:
    ```bash
    sfdk package
    ```

---

## License

This application is licensed under the GPLv3 license. See the `LICENSE` file for more details.
