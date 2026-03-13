workspace {
    name "Социальная сеть Facebook"

    # включаем режим с иерархической системой идентификаторов
    !identifiers hierarchical

    model {
        properties { 
            structurizr.groupSeparator "/"
            workspace_cmdb "cmdb_mnemonic"
            architect "Гуреева Алина, М8О-102СВ-25"
        }

        # Пользователи системы
        guest = person "Неавторизированный пользователь (гость)"
        authorized_user_sender = person "Авторизированный пользователь (отправитель)"
        authorized_user_receiver = person "Авторизированный пользователь (получатель)"
        support_staff = person "Сотрудник технической поддержки"

        my_system = softwareSystem "Social network"{
            # Базы данных
            userDb = container "User Database" "Хранит данные пользователей" "PostgreSQL" {
                tags "database"
            }
            wallDb = container "Wall Database" "Хранит записи стены пользователей, комментарии, лайки, репосты" "PostgreSQL" {
                tags "database"
            }
            chatDb = container "Chat Database" "Хранит историю P2P-сообщений, чаты, статус доставки сообщений" "MongoDB" {
                tags "database"
            }
            recommendDb = container "Recomentation Database" "Хранит профили интересов пользователей, веса рекомендаций, историю взаимодействий с контентом" "PostgreSQL" {
                tags "database"
            }

            # Микросервисы

            recommendationService = container "Recommendation Service" "Анализирует поведение пользователей: активность на стене, интересы — формирует профиль для таргетинга рекламы" "Python, FastAPI" {
                -> userDb "Читает информацию о пользователе" "JDBC"
                -> wallDb "Читает/пишет активность на стене" "JDBC"
                -> recommendDb "Читает/пишет" "JDBC"

            }

            chatService = container "Chat Service" "Отправка P2P-сообщений, получение списка сообщений, доставка через WebSocket" "Go, Gorilla WebSocket" {
                -> chatDb "Читает/пишет историю сообщений" "MongoDB Driver"
                -> chatDb "Получение списка сообщения для пользователя" "MongoDB Driver"
            }

            wallService = container "Wall Service" "Добавление записей на стену, загрузка стены пользователя" "Spring Boot" {
                -> wallDb "Читает/пишет записи стены (добавление записи)" "JDBC"
            }

            userService = container "User Service" "Создание пользователя, поиск по маске и логину" "Spring Boot" {
                -> userDb "Проверка существования пользователя" "JDBC"
                 -> userDb "Создание нового пользователя" "JDBC"
                 -> userDb "Поиск пользователя по логину" "JDBC"
                 -> userDb "Поиск пользователя по маске ФИО" "JDBC"
            }

            chatService -> userService "Проверка существования пользователя"

            # API Gateway
            apiGateway = container "API Gateway" "Единая точка входа, маршрутизация, аутентификация" "Spring Cloud Gateway" {
                -> userService "Маршрутизирует запросы /api/users/**" "HTTPS/REST"
                -> wallService "Маршрутизирует запросы /api/wall/**" "HTTPS/REST"
                -> chatService "Маршрутизирует запросы /api/chats/**" "HTTPS/REST"
            }

            # Веб-приложение
            web_app = container "Web Application" "Веб-интерфейс для пользователей" "React" {
                tags "Web Browser"
                -> apiGateway "Осуществление API вызовов" "HTTPS/REST"
            }

            # Мобильное приложение
            mobile_app = container "Mobile Application" "Мобильное приложение для пользователей" "React Native" {
                tags "MobileApp"
                -> apiGateway "Осуществление API вызовов" "HTTPS/REST"
            }

        }

        # Внешние сервисы
        email_service = softwareSystem "Email-сервис" "Отправляет email-уведомления" {
            tags "external"
            -> guest "Отправляет сообщение"
        }
        push_service = softwareSystem "Push-сервис" "Отправляет push-уведомления на устройства" {
            tags "external"
            -> authorized_user_receiver "Отправляет уведомление"
        }
        ads_service = softwareSystem "Реклама" "Система таргетированной рекламы"{
            tags "external"
        }

        # Связи
        guest -> my_system "Регистрация, авторизация, просмотр публичных профилей и стен"
        authorized_user_sender -> my_system "Пишет на стену, отправляет сообщения, видит контент"
        authorized_user_receiver -> my_system "Получает сообщения, видит контент"
        support_staff -> my_system "Модерация пользователей и контента, работает с обращениями и тикетами"
        
        my_system -> email_service "Уведомление об авторизации" "HTTPS/REST"
        my_system -> push_service "Уведомляет о новых постах или сообщениях" "HTTPS/REST"
        my_system -> ads_service "Получение рекламы" "HTTPS/REST"

        guest -> my_system.web_app "Открывает сайт" "HTTPS"
        guest -> my_system.mobile_app "Открывает приложение" "HTTPS"

        authorized_user_sender -> my_system.web_app "Открывает сайт" "HTTPS"
        authorized_user_sender -> my_system.mobile_app "Открывает приложение" "HTTPS"
        authorized_user_receiver -> my_system.web_app "Открывает сайт" "HTTPS"
        authorized_user_receiver -> my_system.mobile_app "Открывает приложение" "HTTPS"

        support_staff -> my_system.web_app "Открывает сайт и использует админ-панель и панель поддержки" "HTTPS"

        my_system.userService -> email_service "Уведомляет о регистрации" "HTTPS"
        my_system.wallService -> push_service "Уведомляет о новом посте" "HTTPS"
        my_system.chatService -> push_service "Уведомляет о новом сообщении" "HTTPS"
        my_system.wallService -> my_system.recommendationService "Загрузка стены пользователя"
        my_system.recommendationService -> ads_service "Подбор на основе интересов"

    }

    views {
        # Конфигурируем настройки отображения plant uml
        properties {
            plantuml.format     "svg"
            kroki.format        "svg"
            structurizr.sort created
            structurizr.tooltips true
        }

        # Задаем стили для отображения
        themes default


        # Диаграмма контекста
        systemContext my_system {
            include *
            autoLayout lr
        }

        container my_system {
            include *
            autoLayout lr
        }

        dynamic my_system "SendMessage" "Динамическая диаграмма процесса отправки P2P-сообщения" {
            1:  authorized_user_sender -> my_system.web_app "Вводит текст и нажимает отправить"
            2:  my_system.web_app -> my_system.apiGateway "POST /api/chats/messages (получатель, текст)"
            3:  my_system.apiGateway -> my_system.chatService "POST /messages (те же данные)"
            4:  my_system.chatService -> my_system.userService "Проверяет существование получателя по id"
            5:  my_system.userService -> my_system.userDb "Поиск пользователя по id"
            6:  my_system.userDb -> my_system.userService "Возвращает данные пользователя"
            7:  my_system.userService -> my_system.chatService "Получатель найден"
            8:  my_system.chatService -> my_system.chatDb "Сохраняет сообщение со статусом Отправлено"
            9:  my_system.chatDb -> my_system.chatService "Подтверждение сохранения, возвращает id сообщения"
            10: my_system.chatService -> push_service "Уведомляет получателя о новом сообщении"
            11: push_service -> authorized_user_receiver "Доставляет push-уведомление"
            12: my_system.chatService -> my_system.apiGateway "Возвращает успешный ответ с id сообщения"
            13: my_system.apiGateway -> my_system.web_app "Возвращает ответ"
            14: my_system.web_app -> authorized_user_sender "Отображает сообщение как доставленное"
            autoLayout
        }

        styles {
            element "database" {
                shape Cylinder
                background #E6E6FA  
                color #000000       
            }
            element "Web Browser" {
                shape WebBrowser
                background #B8D4E3  
                color #000000
            }
            element "MobileApp" {
                shape MobileDevicePortrait
                background #F599CE  
                color #000000
            }
            element "external" {
                background #BBBBBB   
                color #555555        
                border dashed        
}
        }
    }
}