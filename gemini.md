# Project Name (vkdby)

## Overview
This project is a Ruby on Rails application for creating and managing a database of Visual Kei bands (Units) and band members (People). It allows tracking the history of members joining and leaving bands, managing profile information, and linking to external resources.

## Architecture

*   **Backend:** Ruby on Rails
*   **Database:** MySQL
*   **Frontend Check:** Tailwind CSS
*   **Testing:** Minitest

## Key Features

*   **Unit Management:** Create and manage bands (Units).
*   **Person Management:** Create and manage band members (People).
*   **History Tracking:** comprehensive log system (`PersonLog`, `UnitLog`) to track career history (joins, leaves, formation, disbandment, etc.).
*   **Aliases:** Support for custom status text (e.g., "卒業" instead of "脱退").
*   **Admin Interface:** Dedicated admin interfaces for managing data.

## Development Setup

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/kuwavkdb/vkdby.git
    cd vkdby
    ```

2.  **Install dependencies:**
    ```bash
    bundle install
    ```

3.  **Setup database:**
    ```bash
    rails db:create
    rails db:migrate
    ```

4.  **Start the server:**
    ```bash
    bin/rails server
    ```
