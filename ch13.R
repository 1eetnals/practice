connectionDetails <- Eunomia::getEunomiaConnectionDetails()
Eunomia::createCohorts(connectionDetails)

#####13.1.PatientLevelPrediction R 패키지 사용해 예측에 사용할 공변량 정의하고 CDM에서 PLP 데이터를 추출하고 PLP데이터 요약
library(PatientLevelPrediction)
library(CohortMethod)
library(ff)

#공변량 설정의 모음 지정
covSettings <- createCovariateSettings(  
  useDemographicsGender = TRUE,
  useDemographicsAge = TRUE,
  useConditionGroupEraLongTerm = TRUE,
  useConditionGroupEraAnyTimePrior = TRUE,
  useDrugGroupEraLongTerm = TRUE,
  useDrugGroupEraAnyTimePrior = TRUE,
  useVisitConceptCountLongTerm = TRUE,
  longTermStartDays = -365,
  endDays = -1)

#getPlpData 데이터베이스에서 데이터 추출위해 사용 > 여기서 부터 오류남
plpData <- getPlpData(connectionDetails = connectionDetails,
                      cdmDatabaseSchema = "main",
                      cohortDatabaseSchema = "main",
                      cohortTable = "cohort",
                      cohortId = 4,
                      covariateSettings = covSettings,
                      outcomeDatabaseSchema = "main",
                      outcomeTable = "cohort",
                      outcomeIds = 3)
summary(plpData)

#####13.2.최종 대상 모집단을 정의하기 위해 연구 선택사항을 다시 살펴보고 createStudyPopulation 함수를 사용해 이를 지정하라. 선택한 것이 최종 모집단의 크기에 어떤 영향을 미칠 것인가
population <- createStudyPopulation(plpData = plpData,
                                   outcomeId = 3,
                                   washoutPeriod = 364,
                                   firstExposureOnly = FALSE,
                                   removeSubjectsWithPriorOutcome = TRUE,
                                   priorOutcomeLookback = 9999,
                                   riskWindowStart = 1,  #대상 코호트 시작에 관련된 위험 기간 risk window의 시작과 끝을 지정
                                   riskWindowEnd = 365,
                                   addExposureDaysToStart = FALSE,  #True일 경우 코호트 시간을 시작일에 추가 가능
                                   addExposureDaysToEnd = FALSE,
                                   minTimeAtRisk = 364,     #최소 위험에 노출된 시간을 적용 가능
                                   requireTimeAtRisk = TRUE,  
                                   includeAllOutcomes = TRUE)  #이것이 결과를 가진 환자에게도 적용되는지 여부 지정 가능
nrow(population)
#관심결과의 연구 모집단을 생성하고, 364일의 위험 노출 시간 time-at-risk이 필요하며, NSAI 시작하기 전 결과를 경험한 피험자 제거
#이 경우 사전의 결과를 가진 피험자를 제거하고, 최소 364일의 위험 노출 기간을 요구하기 때문에 몇 사람들을 잃게 됌,

#####13.3.LASSO 사용해 예측 모델 만들고 Shiny 앱을 사용해 성능 평가, 모델 성능은?
#먼저 모델 설정 객체 만든후, runPlp 기능 호출함으로써 LASSO 모델 실행
lassoModel <- setLassoLogisticRegression(seed = 0)
lassoResults <- runPlp(population = population,
                       plpData = plpData,
                       modelSettings = lassoModel,
                       testSplit = 'person',
                       testFraction = 0.25,  #25프로로 평가
                       nfold = 2,
                       splitSeed = 0)
viewPlp(lassoResults)  #Shiny앱 사용해 결과 보기
