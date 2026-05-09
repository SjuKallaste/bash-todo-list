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
        id=$(    echo "$line" | cut -d',' -f1)
        title=$( echo "$line" | cut -d',' -f2)
        status=$(echo "$line" | cut -d',' -f3)
        date=$(  echo "$line" | cut -d',' -f4)
        notes=$( echo "$line" | cut -d',' -f5-)
        printf "%-4s  %-28s  %-10s  %-12s  %s\n" "$id" "$title" "$status" "$date" "$notes"
    done
}

edit_task() {
    view_tasks

    printf "Task ID to edit: "
    read -r target_id

    if [[ ! "$target_id" =~ ^[0-9]+$ ]]; then
        printf "Error: ID must be a number.\n"
        return 1
    fi

    if ! id_exists "$target_id"; then
        printf "Error: no task with ID %s.\n" "$target_id"
        return 1
    fi

    local current_line cur_title cur_status cur_date cur_notes
    current_line=$(grep "^${target_id}," "$CSV_FILE")
    cur_title=$( echo "$current_line" | cut -d',' -f2)
    cur_status=$(echo "$current_line" | cut -d',' -f3)
    cur_date=$(  echo "$current_line" | cut -d',' -f4)
    cur_notes=$( echo "$current_line" | cut -d',' -f5-)

    printf "Leave blank to keep the current value.\n"

    local new_title new_date new_notes
    printf "New title [%s]: " "$cur_title"
    read -r new_title
    [[ -z "${new_title// }" ]] && new_title="$cur_title"
    new_title="${new_title//,/;}"

    printf "New date [%s] (YYYY-MM-DD): " "$cur_date"
    read -r new_date
    if [[ -z "${new_date// }" ]]; then
        new_date="$cur_date"
    elif [[ ! "$new_date" =~ ^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$ ]]; then
        printf "Error: invalid date format. Keeping current date.\n"
        new_date="$cur_date"
    fi

    printf "New notes [%s]: " "$cur_notes"
    read -r new_notes
    [[ -z "${new_notes// }" ]] && new_notes="$cur_notes"
    new_notes="${new_notes//,/;}"

    local new_line tmp
    new_line="${target_id},${new_title},${cur_status},${new_date},${new_notes}"
    tmp=$(mktemp)

    while IFS= read -r row; do
        if [[ "$row" == ${target_id},* ]]; then
            printf "%s\n" "$new_line"
        else
            printf "%s\n" "$row"
        fi
    done < "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "Task #%s updated.\n" "$target_id"
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
    printf "3) Edit Task\n"
    printf "4) Delete Task\n"
    printf "5) Mark as Done\n"
    printf "0) Quit\n"
    printf "Choice: "
    read -r choice

    case "$choice" in
        1) add_task    ;;
        2) view_tasks  ;;
        3) edit_task   ;;
        4) delete_task ;;
        5) mark_done   ;;
        0) printf "Goodbye.\n"; exit 0 ;;
        *) printf "Invalid option.\n" ;;
    esac

    printf "\nPress Enter to continue..."
    read -r _
done
