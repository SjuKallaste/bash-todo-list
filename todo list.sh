CSV_FILE="tasks.csv"
CSV_HEADER="ID,Title,Status,Date,Notes"
STATUS_PENDING="Pending"
STATUS_DONE="Done"

init_storage() {
    if [[ ! -f "$CSV_FILE" ]]; then
        printf "%s\n" "$CSV_HEADER" > "$CSV_FILE"
    fi
}

next_id() {
    local max_id=0 id
    mapfile -t lines < <(tail -n +2 "$CSV_FILE")
    for line in "${lines[@]}"; do
        id=$(echo "$line" | cut -d',' -f1)
        id="${id//[^0-9]/}"
        if [[ -n "$id" && "$id" -gt "$max_id" ]]; then
            max_id=$id
        fi
    done
    printf "%d" $(( max_id + 1 ))
}

id_exists() {
    grep -q "^${1}," "$CSV_FILE" 2>/dev/null
}

add_task() {
    local title date notes new_id today
    today=$(date +%Y-%m-%d)

    printf "Title: "
    read -r title
    if [[ -z "${title// }" ]]; then
        printf "Error: title cannot be empty.\n"
        return 1
    fi

    printf "Due date [YYYY-MM-DD, Enter = today (%s)]: " "$today"
    read -r date
    if [[ -z "$date" ]]; then
        date="$today"
    elif [[ ! "$date" =~ ^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$ ]]; then
        printf "Error: invalid date format.\n"
        return 1
    fi

    printf "Notes (optional): "
    read -r notes

    title="${title//,/;}"
    notes="${notes//,/;}"
    new_id=$(next_id)

    printf "%s,%s,%s,%s,%s\n" "$new_id" "$title" "$STATUS_PENDING" "$date" "$notes" >> "$CSV_FILE"
    printf "Task #%s added.\n" "$new_id"
}

view_tasks() {
    mapfile -t lines < <(tail -n +2 "$CSV_FILE")

    if [[ ${#lines[@]} -eq 0 ]]; then
        printf "No tasks found.\n"
        return
    fi

    printf "%-4s  %-28s  %-10s  %-12s  %s\n" "ID" "Title" "Status" "Date" "Notes"
    printf "%s\n" "--------------------------------------------------------------------"

    for line in "${lines[@]}"; do
        [[ -z "$line" ]] && continue
        local id title status date notes
        id=$(echo "$line" | cut -d',' -f1)
        title=$(echo "$line" | cut -d',' -f2)
        status=$(echo "$line" | cut -d',' -f3)
        date=$(echo "$line" | cut -d',' -f4)
        notes=$(echo "$line" | cut -d',' -f5-)
        printf "%-4s  %-28s  %-10s  %-12s  %s\n" "$id" "$title" "$status" "$date" "$notes"
    done
}

delete_task() {
    view_tasks

    printf "Task ID to delete: "
    read -r target_id

    if [[ ! "$target_id" =~ ^[0-9]+$ ]]; then
        printf "Error: ID must be a number.\n"
        return 1
    fi

    if ! id_exists "$target_id"; then
        printf "Error: no task with ID %s.\n" "$target_id"
        return 1
    fi

    printf "Delete task #%s? [y/N]: " "$target_id"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "Cancelled.\n"
        return
    fi

    local tmp
    tmp=$(mktemp)
    grep -v "^${target_id}," "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "Task #%s deleted.\n" "$target_id"
}

mark_done() {
    view_tasks

    printf "Task ID to mark as done: "
    read -r target_id

    if [[ ! "$target_id" =~ ^[0-9]+$ ]]; then
        printf "Error: ID must be a number.\n"
        return 1
    fi

    if ! id_exists "$target_id"; then
        printf "Error: no task with ID %s.\n" "$target_id"
        return 1
    fi

    local current_status
    current_status=$(grep "^${target_id}," "$CSV_FILE" | cut -d',' -f3)
    if [[ "$current_status" == "$STATUS_DONE" ]]; then
        printf "Task #%s is already done.\n" "$target_id"
        return
    fi

    local tmp
    tmp=$(mktemp)
    while IFS= read -r row; do
        if [[ "$row" == ${target_id},* ]]; then
            printf "%s\n" "$row" | sed "s/,${STATUS_PENDING},/,${STATUS_DONE},/"
        else
            printf "%s\n" "$row"
        fi
    done < "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "Task #%s marked as done.\n" "$target_id"
}

    while true; do
        printf "\n"
        printf "1) Add Task\n"
        printf "2) View Tasks\n"
        printf "3) Delete Task\n"
        printf "4) Mark as Done\n"
        printf "0) Quit\n"
        printf "Choice: "
        read -r choice

        case "$choice" in
            1) add_task    ;;
            2) view_tasks  ;;
            3) delete_task ;;
            4) mark_done   ;;
            0) printf "Goodbye.\n"; exit 0 ;;
            *) printf "Invalid option.\n" ;;
        esac

        printf "\nPress Enter to continue..."
        read -r _
    done
