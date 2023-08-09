#####9.1. Sql Render
library(SqlRender)

###매개 변수값 대체하기
sql <- 'SELECT * FROM concept WHERE concept_id = @a;'
render(sql, a=123)

sql <- 'SELECT * FROM @x WHRER person_id = @a;'
render(sql, x='observation',a=123)

sql <- 'SELECT * FROM concept WHERE concept_id IN (@a);'
render(sql, a=c(123, 234,345))

###if then else
sql <- 'SELECT * FROM cohort {@x} ? {WHERE subject_id=1};'
render(sql, x=FALSE) # [1] "SELECT * FROM cohort "
render(sql, x=TRUE) # [1] "SELECT * FROM cohort WHERE subject_id=1"

sql <- 'SELECT * FROM cohort {@x==1} ? {WHERE subject_id=1};'
render(sql, x=1)
render(sql, x=2)

sql <- 'SELECT * FROM cohort {@x IN (1,2,3)} ? {WHERE subject_id=1};'
render(sql, x=2)

### 다른 SQL 언어로의 변환
sql <- "SELECT TOP 10 * FROM person;"
translate(sql, targetDialect="postgresql")

sql <- 'SELECT * FROM #children;'
translate(sql, targetDialect='oracle',oracleTempSㄾchema='tempEmulationSchema')

#####9.2. DatabaseConnector
library(DatabaseConnector)
library(Eunomia)
connectionDetails <- getEunomiaConnectionDetails()
connection <- connect(connectionDetails)

querySql(connection, "SELECT COUNT(*) FROM person;")
getTableNames(connection,databaseSchema = 'main')

###연결 생성하기 > 개인db가 있어야 함
#connString <- "jdbc:postgresql://localhost:5432/postgres"
#conn <- connect(dbms='postgresql',
#                server='localhost/postgres',
#                user='joe',
#                password='secret',
#                schema='cdm')
disconnect(connection)

###쿼리하기
#데이터베이스 쿼리를 위한 주요함수는 querySql, executeSql
querySql(connection, 'SELECT * FROM person')
querySql(connection, 'SELECT TOP 3 * FROM person')  #오류
executeSql(connection, 'TRUNCATE TABLE foo; DROP TABLE foo;')  #오류
### ffdf객체 사용해 쿼리
x<-querySql.ffdf(connection, 'SELECT * FROM person')  #오류
###같은 sql 사용해 다른 플랫폼 쿼리
x<-renderTranslateQuerySql(connection, 
                           sql='SELECT TOP 10 * FROM @schema.person',
                           schema='cdm_synpuf')  #오류
###테이블 삽입하기
data(mtcars)
insertTable(connection, 'mtcars',mtcars, createTable=TRUE)  #오류

#####9.3. CDM 쿼리 실행
#####9.7. SQL과 R을 사용해 연구 구현 > 오류
library(DatabaseConnector)
conn <- connect(dbms = "postgresql",
                server = "localhost/postgres",
                user = "joe",
                password = "secret")
cdmDbSchema <- "cdm"
cohortDbSchema <- "scratch"
cohortTable <- "my_cohorts"
sql <- "
CREATE TABLE @cohort_db_schema.@cohort_table (
cohort_definition_id INT,
cohort_start_date DATE,
cohort_end_date DATE,
subject_id BIGINT
);
"
renderTranslateExecuteSql(conn, sql,
                          cohort_db_schema = cohortDbSchema,
                          cohort_table = cohortTable)



#####예제
###9.1. SQL과 R을 사용해 데이터베이스에 몇 사람이 있는지 계산
#PERSON 쿼리해 사람의 수 계산
library(DatabaseConnector)
connection <- connect(connectionDetails)
sql <- 'SELECT COUNT(*) AS person_count FROM @cdm.person;'
renderTranslateQuerySql(connection, sql, cdm='main')
disconnect(connection)

###9.2. SQL과 R을 사용해 celecoxib을 적어도 한번 이상 처방 한 사람 계산
library(DatabaseConnector)
connection <- connect(connectionDetails)
sql <- "SELECT COUNT(DISTINCT(person_id)) AS person_count
FROM @cdm.drug_exposure
INNER JOIN @cdm.concept_ancestor
ON drug_concept_id = descendant_concept_id
INNER JOIN @cdm.concept ingredient
ON ancestor_concept_id = ingredient.concept_id
WHERE LOWER(ingredient.concept_name) = 'celecoxib'
AND ingredient.concept_class_id = 'Ingredient'
AND ingredient.standard_concept = 'S';"
renderTranslateQuerySql(connection, sql, cdm = "main")
disconnect(connection)

###9.3. SQL과 R을 사용해 celecoxib에 노출되는 동안 얼마나 많은 위장 출혈이 있는지 진단(위장출혈 개념 ID는 192671)
library(DatabaseConnector)
connection <- connect(connectionDetails)
sql <- "SELECT COUNT(*) AS diagnose_count
FROM @cdm.drug_era
INNER JOIN @cdm.concept ingredient
ON drug_concept_id = ingredient.concept_id
INNER JOIN @cdm.condition_occurrence
ON condition_start_date >= drug_era_start_date
AND condition_start_date <= drug_era_end_date
INNER JOIN @cdm.concept_ancestor
ON condition_concept_id =descendant_concept_id
WHERE LOWER(ingredient.concept_name) = 'celecoxib'
AND ingredient.concept_class_id = 'Ingredient'
AND ingredient.standard_concept = 'S'
AND ancestor_concept_id = 192671;"
renderTranslateQuerySql(connection, sql, cdm='main')
disconnect(connection)
