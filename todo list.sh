CSV_FILE="tasks.csv"
CSV_HEADER="ID,Title,Status,Date,Notes"
STATUS_PENDING="Pending"
STATUS_DONE="Done"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

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

validate_not_empty() {
    if [[ -z "${1// }" ]]; then
        printf "${RED}Error: %s cannot be empty.${RESET}\n" "$2" >&2
        return 1
    fi
}

validate_date() {
    if [[ ! "$1" =~ ^[0-9]{4}-[0-1][0-9]-[0-3][0-9]$ ]]; then
        printf "${RED}Error: date must be YYYY-MM-DD.${RESET}\n" >&2
        return 1
    fi
}

validate_id() {
    if [[ ! "$1" =~ ^[0-9]+$ ]]; then
        printf "${RED}Error: ID must be a number.${RESET}\n" >&2
        return 1
    fi
    if ! grep -q "^${1}," "$CSV_FILE" 2>/dev/null; then
        printf "${RED}Error: no task with ID %s.${RESET}\n" "$1" >&2
        return 1
    fi
}

prompt_id() {
    local id
    while true; do
        printf "Task ID: " >&2
        read -r id
        validate_not_empty "$id" "ID" || continue
        validate_id "$id" && break
    done
    printf "%s" "$id"
}

prompt_date() {
    local label="$1" current="$2" date
    while true; do
        printf "%s [%s] (YYYY-MM-DD, Enter = keep): " "$label" "$current" >&2
        read -r date
        if [[ -z "${date// }" ]]; then
            printf "%s" "$current"
            return
        fi
        validate_date "$date" && break
    done
    printf "%s" "$date"
}

add_task() {
    local title date notes new_id today
    today=$(date +%Y-%m-%d)

    while true; do
        printf "Title: "
        read -r title
        validate_not_empty "$title" "Title" && break
    done

    while true; do
        printf "Due date [YYYY-MM-DD, Enter = today (%s)]: " "$today"
        read -r date
        if [[ -z "$date" ]]; then date="$today"; break; fi
        validate_date "$date" && break
    done

    printf "Notes (optional): "
    read -r notes

    title="${title//,/;}"
    notes="${notes//,/;}"
    new_id=$(next_id)

    printf "%s,%s,%s,%s,%s\n" "$new_id" "$title" "$STATUS_PENDING" "$date" "$notes" >> "$CSV_FILE"
    printf "${GREEN}Task #%s added.${RESET}\n" "$new_id"
}

view_tasks() {
    mapfile -t lines < <(tail -n +2 "$CSV_FILE")

    if [[ ${#lines[@]} -eq 0 ]]; then
        printf "${YELLOW}No tasks found.${RESET}\n"
        return
    fi

    printf "${BOLD}${CYAN}%-4s  %-28s  %-10s  %-12s  %s${RESET}\n" "ID" "Title" "Status" "Date" "Notes"
    printf "%s\n" "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"

    for line in "${lines[@]}"; do
        [[ -z "$line" ]] && continue
        local id title status date notes colour
        id=$(echo "$line" | cut -d',' -f1)
        title=$(echo "$line" | cut -d',' -f2)
        status=$(echo "$line" | cut -d',' -f3)
        date=$(echo "$line" | cut -d',' -f4)
        notes=$(echo "$line" | cut -d',' -f5-)
        if [[ "$status" == "$STATUS_DONE" ]]; then
            colour="$GREEN"
        else
            colour="$YELLOW"
        fi
        printf "${colour}%-4s  %-28s  %-10s  %-12s  %s${RESET}\n" "$id" "$title" "$status" "$date" "$notes"
    done
}

edit_task() {
    view_tasks
    local target_id
    target_id=$(prompt_id)

    local current_line cur_title cur_status cur_date cur_notes
    current_line=$(grep "^${target_id}," "$CSV_FILE")
    cur_title=$(echo "$current_line" | cut -d',' -f2)
    cur_status=$(echo "$current_line" | cut -d',' -f3)
    cur_date=$(echo "$current_line" | cut -d',' -f4)
    cur_notes=$(echo "$current_line" | cut -d',' -f5-)

    printf "Leave blank to keep the current value.\n"

    local new_title new_date new_notes
    printf "New title [%s]: " "$cur_title"
    read -r new_title
    [[ -z "${new_title// }" ]] && new_title="$cur_title"
    new_title="${new_title//,/;}"

    new_date=$(prompt_date "New date" "$cur_date")

    printf "New notes [%s]: " "$cur_notes"
    read -r new_notes
    [[ -z "${new_notes// }" ]] && new_notes="$cur_notes"
    new_notes="${new_notes//,/;}"

    local tmp
    tmp=$(mktemp)
    while IFS= read -r row; do
        if [[ "$row" == ${target_id},* ]]; then
            printf "%s,%s,%s,%s,%s\n" "$target_id" "$new_title" "$cur_status" "$new_date" "$new_notes"
        else
            printf "%s\n" "$row"
        fi
    done < "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "${GREEN}Task #%s updated.${RESET}\n" "$target_id"
}

delete_task() {
    view_tasks
    local target_id confirm tmp
    target_id=$(prompt_id)

    printf "${RED}Delete task #%s? [y/N]: ${RESET}" "$target_id"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        printf "Cancelled.\n"
        return
    fi

    tmp=$(mktemp)
    grep -v "^${target_id}," "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "${GREEN}Task #%s deleted.${RESET}\n" "$target_id"
}

mark_done() {
    view_tasks
    local target_id tmp current_status
    target_id=$(prompt_id)

    current_status=$(grep "^${target_id}," "$CSV_FILE" | cut -d',' -f3)
    if [[ "$current_status" == "$STATUS_DONE" ]]; then
        printf "${YELLOW}Task #%s is already done.${RESET}\n" "$target_id"
        return
    fi

    tmp=$(mktemp)
    while IFS= read -r row; do
        if [[ "$row" == ${target_id},* ]]; then
            printf "%s\n" "$row" | sed "s/,${STATUS_PENDING},/,${STATUS_DONE},/"
        else
            printf "%s\n" "$row"
        fi
    done < "$CSV_FILE" > "$tmp"
    mv "$tmp" "$CSV_FILE"

    printf "${GREEN}Task #%s marked as done.${RESET}\n" "$target_id"
}

search_tasks() {
    local keyword
    while true; do
        printf "Search keyword: "
        read -r keyword
        validate_not_empty "$keyword" "Keyword" && break
    done

    mapfile -t lines < <(tail -n +2 "$CSV_FILE")
    local found=0

    for line in "${lines[@]}"; do
        [[ -z "$line" ]] && continue
        if echo "$line" | grep -qi "$keyword"; then
            found=1
            local id title status date
            id=$(echo "$line" | cut -d',' -f1)
            title=$(echo "$line" | cut -d',' -f2)
            status=$(echo "$line" | cut -d',' -f3)
            date=$(echo "$line" | cut -d',' -f4)
            printf "%-4s  %-28s  %-10s  %s\n" "$id" "$title" "$status" "$date"
        fi
    done

    if [[ $found -eq 0 ]]; then
        printf "${YELLOW}No tasks matched \"%s\".${RESET}\n" "$keyword"
    fi
}

show_stats() {
    mapfile -t lines < <(tail -n +2 "$CSV_FILE")

    local total=0 done_count=0 pending_count=0

    for line in "${lines[@]}"; do
        [[ -z "$line" ]] && continue
        (( total++ ))
        local status
        status=$(echo "$line" | cut -d',' -f3)
        case "$status" in
            "$STATUS_DONE")    (( done_count++    )) ;;
            "$STATUS_PENDING") (( pending_count++ )) ;;
        esac
    done

    printf "Total   : %d\n" "$total"
    printf "${GREEN}Done    : %d${RESET}\n" "$done_count"
    printf "${YELLOW}Pending : %d${RESET}\n" "$pending_count"

    if [[ $total -gt 0 ]]; then
        local filled=$(( done_count * 20 / total ))
        local empty=$(( 20 - filled ))
        local bar="" i
        for (( i=0; i<filled; i++ )); do bar+="#"; done
        for (( i=0; i<empty;  i++ )); do bar+="-"; done
        printf "Progress [${GREEN}%s${RESET}] %d%%\n" "$bar" $(( done_count * 100 / total ))
    fi
}

    while true; do
        clear

        local total pending done_c
        total=$(tail -n +2 "$CSV_FILE" | grep -c '.' || true)
        pending=$(tail -n +2 "$CSV_FILE" | grep -c ",${STATUS_PENDING}," || true)
        done_c=$(tail -n +2 "$CSV_FILE" | grep -c ",${STATUS_DONE}," || true)

        printf "${BOLD}${CYAN}To-Do List${RESET}   %d total  ${YELLOW}%d pending${RESET}  ${GREEN}%d done${RESET}\n" \
            "$total" "$pending" "$done_c"
        printf "%s\n" "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
        printf "1) Add Task\n"
        printf "2) View Tasks\n"
        printf "3) Edit Task\n"
        printf "4) Delete Task\n"
        printf "5) Mark as Done\n"
        printf "6) Search\n"
        printf "7) Stats\n"
        printf "0) Quit\n"
        printf "%s\n" "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
        printf "Choice: "
        read -r choice

        case "$choice" in
            1) add_task ;;
            2) view_tasks ;;
            3) edit_task ;;
            4) delete_task ;;
            5) mark_done ;;
            6) search_tasks ;;
            7) show_stats ;;
            0) printf "${GREEN}Goodbye.${RESET}\n"; exit 0 ;;
            *) printf "${RED}Invalid option.${RESET}\n" ;;
        esac

        printf "\nPress Enter to continue..."
        read -r _
    done

init_storage
main_menu
