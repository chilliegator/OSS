#!/bin/bash

# Функция для вывода справки
show_help() {
    cat <<EOF
Использование: $0 [OPTIONS]

Опции:
  -u, --users         Выводит перечень пользователей и их домашних директорий
  -p, --processes     Выводит перечень запущенных процессов (номер и название)
  -h, --help          Выводит данную справку
  -l PATH, --log PATH    Замещает вывод на экран выводом в файл по заданному пути PATH
  -e PATH, --errors PATH   Замещает вывод ошибок из потока stderr в файл по заданному пути PATH

Примеры:
  $0 --users
  $0 --processes --log output.txt
  $0 --users --log output.txt
  $0 --users --errors error.log
  $0 --processes --errors error.log
  $0 --users --errors --log output.log
  $0 --processes --errors --log output.log
EOF
    exit 0
}

# Функция для вывода пользователей и их домашних директорий
list_users() {
    getent passwd | awk -F: '$3 >= 1000 {print $1 "\t" $6}' /etc/passwd | sort
}

# Функция для вывода запущенных процессов
list_processes() {
    ps -eo pid,cmd,start --sort=pid
}

# Функция для проверки доступа к пути
check_path() {
    local path=$1
    if [ ! -e "$path" ]; then
        touch "$path"
    fi
    if [ ! -w "$path" ]; then
        log_error "Ошибка записи в файл $path"
        exit 1
    fi
}

# Функция для логирования ошибок
log_error() {
    local message="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [ERROR] $message" | tee -a "$ERROR_FILE"
}

# Функция для проверки пути
validate_path() {
    local path="$1"
    if [[ ! -d "$(dirname "$path")" ]]; then
        log_error "Ошибка: директория для файла '$path' не существует или недоступна для записи."
        return 1
    fi
    return 0
}

# Основная функция
main() {
    local log_path=""
    local error_path=""
    local action=""

    # Парсинг аргументов с помощью getopt
    TEMP=$(getopt -o upl:e:h --long users,processes,log:,errors:,help -n "$0" -- "$@")
    if [[ $? -ne 0 ]]; then
        log_error "Ошибка: неверные параметры."
        show_help
        exit 1
    fi
    eval set -- "$TEMP"

    # Обработка аргументов
    while true; do
        case "$1" in
            -u|--users)
                action="users"
                shift
                ;;
            -p|--processes)
                action="processes"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--log)
                log_path="$2"
                shift 2
                ;;
            -e|--errors)
                error_path="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            *)
                log_error "Ошибка: неизвестный параметр $1."
                show_help
                exit 1
                ;;
        esac
    done

    # Проверка и установка log path
    if [[ -n "$log_path" ]]; then
        validate_path "$log_path" || exit 1
        exec >"$log_path"
    fi

    # Проверка и установка вывода ошибок
    if [[ -n "$error_path" ]]; then
        validate_path "$error_path" || exit 1
        exec 2>"$error_path"
    else
        ERROR_FILE="error_log.txt"
        check_path "$ERROR_FILE"
        exec 2> >(tee -a "$ERROR_FILE" >&2)
    fi

    # Выполнение действий
    case "$action" in
        users)
            list_users
            ;;
        processes)
            list_processes
            ;;
        *)
            log_error "Ошибка: действие не задано."
            show_help
            exit 1
            ;;
    esac
}

main "$@"
