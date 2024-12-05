#!/bin/bash

# Функция для вывода справки
print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -u, --users                Выводит перечень пользователей и их домашних директорий"
    echo "  -p, --processes           Выводит перечень запущенных процессов"
    echo "  -h, --help                Выводит справку"
    echo "  -l, --log PATH            Замещает вывод на экран выводом в файл по заданному пути PATH"
    echo "  -e, --errors PATH         Замещает вывод ошибок из потока stderr в файл по заданному пути PATH"
}

# Функция для вывода пользователей и их домашних директорий
list_users() {
    if [ -n "$LOG_FILE" ]; then
        cut -d: -f1,6 /etc/passwd | sort | tee "$LOG_FILE"
    else
        cut -d: -f1,6 /etc/passwd | sort
    fi
}

# Функция для вывода запущенных процессов
list_processes() {
    if [ -n "$LOG_FILE" ]; then
        ps -e -o pid,comm | sort -n | tee "$LOG_FILE"
    else
        ps -e -o pid,comm | sort -n
    fi
}

# Функция для проверки доступа к пути
check_path() {
    local path="$1"
    if [ ! -w "$path" ]; then
        echo "Ошибка: нет доступа для записи в файл $path" >&2
        exit 1
    fi
}

# Обработка аргументов командной строки
while getopts "upl:e:h-:" opt; do
    case "$opt" in
        u) LIST_USERS=true ;;
        p) LIST_PROCESSES=true ;;
        l) LOG_FILE="$OPTARG"; check_path "$LOG_FILE" ;;
        e) ERROR_FILE="$OPTARG"; check_path "$ERROR_FILE" ;;
        h) print_help; exit 0 ;;
        -)
            case "$OPTARG" in
                users) LIST_USERS=true ;;
                processes) LIST_PROCESSES=true ;;
                log) LOG_FILE="${!OPTIND}"; OPTIND=$((OPTIND + 1)); check_path "$LOG_FILE" ;;
                errors) ERROR_FILE="${!OPTIND}"; OPTIND=$((OPTIND + 1)); check_path "$ERROR_FILE" ;;
                help) print_help; exit 0 ;;
                *) echo "Неизвестная опция --$OPTARG" >&2; print_help; exit 1 ;;
            esac
            ;;
        *) echo "Неизвестная опция -$OPTARG" >&2; print_help; exit 1 ;;
    esac
done

# Перенаправление stderr в файл, если указан
if [ -n "$ERROR_FILE" ]; then
    exec 2>"$ERROR_FILE"
fi

# Выполнение действий
if [ "$LIST_USERS" = true ]; then
    list_users
fi

if [ "$LIST_PROCESSES" = true ]; then
    list_processes
fi

# Если не указаны никакие действия, выводим справку
if [ -z "$LIST_USERS" ] && [ -z "$LIST_PROCESSES" ]; then
    print_help
fi
