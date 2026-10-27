Ось готовий вміст для файлу **`INSTRUCTION.md`** у чистому виді. Натисни кнопку **Copy** у правому верхньому кутку блоку з кодом та вставити у свій файл:

```markdown
# Інструкція з перевірки (validation)

Ця інструкція описує, як розгорнути та перевірити helm chart `todoapp` разом із subchart `mysql` у кластері `kind`.

## Вимоги

Встановлені: `docker`, `kind`, `kubectl`, `helm`.

## 1. Розгортання

З кореня репозиторію виконайте:

```bash
chmod +x bootstrap.sh
./bootstrap.sh

```

Скрипт виконує:

1. створення `kind`-кластера з `cluster.yml`;
2. перегляд labels та taints вузлів;
3. taint вузлів з міткою `app=mysql` → `app=mysql:NoSchedule`;
4. встановлення `ingress-nginx`;
5. встановлення `metrics-server` (для HPA);
6. `helm lint` та `helm upgrade --install todoapp ./.infrastructure/helm-chart/todoapp`.

> Якщо namespace у `values.yaml` відрізняється від `todoapp`, запустіть: `NAMESPACE=<ваш-namespace> ./bootstrap.sh`

## 2. Перевірка кластера та вузлів

```bash
kubectl get nodes --show-labels
kubectl describe nodes | grep -E "^Name:|Taints:"

```

Очікується: вузол(и) з міткою `app=mysql` мають taint `app=mysql:NoSchedule`.

## 3. Перевірка helm-релізу

```bash
helm list -A
helm status todoapp
helm get values todoapp --all

```

Очікується: реліз `todoapp` зі статусом `deployed`.

Перевірка залежності та шаблонів:

```bash
helm dependency list ./.infrastructure/helm-chart/todoapp
helm template todoapp ./.infrastructure/helm-chart/todoapp | less

```

## 4. Перевірка ресурсів

```bash
kubectl get all,cm,secret,ing,pv,pvc,hpa -A

```

Очікується:

* namespace із `values.yaml` створений;
* імена ресурсів мають префікс `todoapp` (`.Chart.Name`), у subchart: `mysql`;
* Pod-и `todoapp` та `mysql-0` у статусі `Running`;
* `mysql` StatefulSet працює на вузлі з міткою `app=mysql` (через toleration та affinity);
* PVC у статусі `Bound`;
* HPA показує метрики CPU/Memory (не `<unknown>`).

Перевірка, на якому вузлі працює mysql:

```bash
kubectl get pods -A -o wide | grep mysql

```

## 5. Перевірка параметрів з `values.yaml`

Змініть значення (наприклад, репліки mysql) та оновіть реліз:

```bash
helm upgrade todoapp ./.infrastructure/helm-chart/todoapp --set mysql.replicaCount=2
kubectl get statefulset -A

```

Перевірте інші параметри (resources, RollingUpdate, image tag, HPA min/max, ServiceAccount) через:

```bash
kubectl get deployment -A -o yaml | less
kubectl get hpa -A -o yaml | less

```

## 6. Перевірка Secrets та змінних середовища

```bash
kubectl get secret -A
kubectl exec -n <namespace> deploy/todoapp-deployment -- env | sort

```

Очікується: змінні середовища з Secret присутні в контейнері.

## 7. Перевірка застосунку

Через NodePort (див. `kubectl get svc -A`) або Ingress:

```bash
kubectl get ing -A
curl -I http://localhost/

```

## 8. Генерація `output.log`

```bash
kubectl get all,cm,secret,ing -A > output.log

```

## 9. Очищення

```bash
helm uninstall todoapp
kind delete cluster

```

## Структура, яку очікує CI

```
.
├── bootstrap.sh
├── cluster.yml
├── output.log
├── INSTRUCTION.md
└── .infrastructure/
    └── helm-chart/
        └── todoapp/
            ├── Chart.yaml        # містить dependencies: - name: mysql
            ├── values.yaml
            ├── templates/
            └── charts/
                └── mysql/        # subchart (Chart.yaml, values.yaml, templates/)

```

```

<FollowUp label="Потрібні команди для перевірки статусу та пушу в гит?" query="Дай команди щоб задодати всі зміни і запушити в гит"/>

```