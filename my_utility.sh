#!/bin/bash

# -h, --help        Функция для вывода справки
show_help() {
    echo "Использование: $0 [OPTIONS]"
    echo "[OPTIONS]:"
    echo "  -h, --help          Выводит данную справку"
    echo "  -u, --users         Выводит перечень пользователей и их домашних директорий"
    echo "  -p, --processes     Выводит перечень запущенных процессов (номер и название)"
    echo "  -l, --log PATH      Замещает вывод на экран выводом в файл по заданному пути PATH"
    echo "  -e, --errors PATH   Замещает вывод ошибок из потока stderr в файл по заданному пути PATH"
}

# -u, --users        Функция для вывода пользователей и их домашних директорий
list_users() {
    getent passwd | awk -F: '{print $1, $6}' | sort
}

# -p, --processes        Функция для вывода запущенных процессов
list_processes() {
    ps -e -o pid,comm | sort -n
}

# Функция для проверки доступа к пути
check_path() {
    local path=$1
    if [ ! -e "$path" ]; then
        touch "$path"
    fi
    if [ ! -w "$path" ]; then
        echo "Ошибка записи в файл $path" >&2
        exit 1
    fi
}

# Обработка аргументов командной строки
TEMP=$(getopt -o uphl:e: --long users,processes,help,log:,errors: -n 'SysInfoHelper.sh' -- "$@")
if [ $? != 0 ]; then
    echo "Ошибка в параметрах" >&2
    show_help
    exit 1
fi

eval set -- "$TEMP"

LOG_FILE=""
ERROR_FILE=""
TEMP_ERROR_FILE=$(mktemp)

while true; do
    case "$1" in
        -u|--users)
            LIST_USERS=true
            shift
            ;;
        -p|--processes)
            LIST_PROCESSES=true
            shift
            ;;
        -l|--log)
            LOG_FILE="$2"
            check_path "$LOG_FILE"
            shift 2
            ;;
        -e|--errors)
            ERROR_FILE="$2"
            check_path "$ERROR_FILE"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Ошибка в параметрах" >&2
            show_help
            exit 1
            ;;
    esac
done

# Перенаправление stderr в файл, если указан
if [ -n "$ERROR_FILE" ]; then
    exec 2> >(tee -a "$TEMP_ERROR_FILE" >&2)
fi

# Перенаправление stdout в файл, если указан
if [ -n "$LOG_FILE" ]; then
    exec > "$LOG_FILE"
fi

# Выполнение действий
if [ "$LIST_USERS" = true ]; then
    list_users
fi

if [ "$LIST_PROCESSES" = true ]; then
    list_processes
fi

# Проверка ошибок и запись сообщения об отсутствии ошибок, если их нет
if [ -s "$TEMP_ERROR_FILE" ]; then
    cat "$TEMP_ERROR_FILE" >> "$ERROR_FILE"
else
    if [ -n "$ERROR_FILE" ]; then
        echo "Ошибок нет" >> "$ERROR_FILE"
    fi
fi

# Удаление временного файла ошибок
rm -f "$TEMP_ERROR_FILE"
