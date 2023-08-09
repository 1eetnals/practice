#####10.2. 
#다음 기준에 따르도록 현재 존재하는 코호트 테이블 안에서 급성 심근경색 Acute Myocardial Infarction 코호트를 SQL과 R로 만들기
#심근경색을 진단 받은 사람 (4329847'심근경색 Myocardial infarction'과 그 하위 개념에서 314666'과거 심근경색 old myocardial infarction과 그 모든 하위 개념 제외하기)
#입원환자 혹은 응급실 방문 환자만 선택 (9201 'impatient visit',9203'emergency room visit',262'emergency room and inpatient visit')

library(DatabaseConnector)
connection<-connect(connectionDetails)

#심근경색의 모든 발생기록 찾고 이를 dignoses라는 임시 테이블에 저장
sql <- "SELECT person_id AS subject_id,
condition_start_date AS cohort_start_date
INTO #diagnoses
FROM @cdm.condition_occurrence
WHERE condition_concept_id IN (
SELECT descendant_concept_id
FROM @cdm.concept_ancestor
WHERE ancestor_concept_id = 4329847 -- Myocardial infarction
)
AND condition_concept_id NOT IN (
SELECT descendant_concept_id
FROM @cdm.concept_ancestor
WHERE ancestor_concept_id = 314666 -- Old myocardial infarction
);"
renderTranslateExecuteSql(connection, sql, cdm = "main")

#몇몇 특별한 COHORT_DEFINITION_ID(우리는 1선택)를 사용해 입원중이거나 응급실에 방문한 환자들에게 일어난 것만 선택
sql <- "INSERT INTO @cdm.cohort (
subject_id,
cohort_start_date,
cohort_definition_id
)
SELECT subject_id,
cohort_start_date,
CAST (1 AS INT) AS cohort_definition_id
FROM #diagnoses
INNER JOIN @cdm.visit_occurrence
ON subject_id = person_id
  AND cohort_start_date >= visit_start_date
  AND cohort_start_date <= visit_end_date
WHERE visit_concept_id IN (9201, 9203, 262); -- Inpatient or ER;"
renderTranslateExecuteSql(connection, sql, cdm = "main")

#임시 테이블은 더이상 필요없으면 정리하는 것 추천
sql <- "TRUNCATE TABLE #diagnoses;
DROP TABLE #diagnoses;"
renderTranslateExecuteSql(connection, sql)

disconnect(connection)