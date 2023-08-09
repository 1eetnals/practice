#####12.1. CohortMethod R패키지 활용해 공변량의 기본 모음 사용하고 CDM에서 CohortMethodData추출, CohortMethodData의 요약본 생성
# 공변량의 기본 모음을 명시하고 있지만 반드시 비교하는 두 개의 약물은 제외하고, 그것의 하위 목록은 포함해야. 

connectionDetails <- Eunomia::getEunomiaConnectionDetails()
Eunomia::createCohorts(connectionDetails)


library(CohortMethod)
nsaids <- c(1118084, 1124300) # celecoxib, diclofenac
covSettings <- createDefaultCovariateSettings(   #코호트를 포함하는 테이블에 함수 지정하고, 해당 테이블의 cohort definition id가 표적, 대조 및 결과 코호트를 식별하도록 지정
  excludedCovariateConceptIds = nsaids,
  addDescendantsToExclude = TRUE)

# Load data:
cmData <- getDbCohortMethodData(
  connectionDetails = connectionDetails,
  cdmDatabaseSchema = "main",
  targetId = 1,
  comparatorId = 2,
  outcomeIds = 3,
  exposureDatabaseSchema = "main",
  exposureTable = "cohort",
  outcomeDatabaseSchema = "main",
  outcomeTable = "cohort",
  covariateSettings = covSettings)

summary(cmData)   #추출한 데이터에 대한 추가 정보 볼수 있음

#####12.2. createStudyPopulation기능을 사용해 연구 집단을 생성하는데 180일의 휴약기간을 가지며, 사전 결과를 가진 사람을 배제하고 두 코호트에 공통으로 나타나는 사람을 제거해야함. 사람의 수 적어지나?
#일반적으로 표적, 대조 코호트와 결과 코호트는 서로 독립적으로 정의됌. 효과 크기 추정치를 생서앟려면 노출 전에 결과가 있는 피험자는 제거하고, 정의한 
studyPop <- createStudyPopulation(
  cohortMethodData = cmData,
  outcomeId = 3,
  washoutPeriod = 180,
  removeDuplicateSubjects = "remove all",
  removeSubjectsWithPriorOutcome = TRUE,
  riskWindowStart = 0,
  startAnchor = "cohort start",
  riskWindowEnd = 99999)
drawAttritionDiagram(studyPop)  #기존의 코호트와 비교해 대상이 달라지지 않음을 확인 > 사용한 제한이 이미 콯틔 정의에서 사용된것이므로


#####12.3. 아무 조정을 사용하지 않고 Cox 비례 위험 모델 만들어라. 이경우 뭐가 잘못되는가
#결과모델은 결과와 어떠한 변수가 관련있는지 설명하는 모델. 엄격한 가정하에 치료변수에 대한 게수는 인과적 영향으로 해석 가능. 
model <- fitOutcomeModel(population=studyPop, modelType="cox")
model
#celecoxib사용자가 diclofenac사용자와 교환 가능하지 않을 가능성 있고, 이러한 기저 과거력의 차이는 이와 같이 outcome상의 차이가 있는 것처럼 결과 나옰 있음. 이 차이 조절 안하면 이 분석과 같이 편향된 측정 생성 가능


#####12.4. 성향 모델 만들어라. 두 집단은 비교되는가
#getDbcohortMethodData()로 생성된 공변량 사용해 성향 점수 모델 적합 가능, 피험자별 성향 점수 계산 가능
ps <- createPs(cohortMethodData = cmData, population=studyPop)
plotPs(ps, showCountsLabel = TRUE, showAucLabel = TRUE)
#성향 모델은 0.63의 AUC를 달성함 > 대상과 대조 코호트를 구분할 수 있음을 의미

#####12.5. 5개의 계층을 사용해 PS 계층화 수행, 공변량 균형은 달성되었는가
#성향점수를 사용하는 목적은 두 군을 비교할 수 있게 만드는 것임. 기저 공변량이 조정 후 실제로 균형을 이루고 있는지 등을 확인하여 이 목적이 달성되었는지 입증해야함. 
strataPop <- stratifyByPs(ps, numberOfStrata = 5)
bal <- computeCovariateBalance(strataPop, cmData)
plotCovariateBalanceScatterPlot(bal,
                                showCovariateCountLabel = TRUE,
                                showMaxLabel = TRUE,
                                beforeLabel = "Before stratification",
                                afterLabel = "After stratification")
#다양한 기저 공변량은 층화전의 큰 표준화된 평균의 차이 보여줌, 층화 후에 최대 표준화 차이와 같이 균형 balance 좋아짐.
# 각 점은 공변량 보여줌

#####12.6. PS strata를 사용해 Cox 비례위험 모델을 구축, 조정되지 않은 모델과 결과가 다른 이유는?
adjModel<- fitOutcomeModel(population=strataPop, modelType='cox',stratified=TRUE)
adjModel
#조정된 추정치는 조정되지않은 추정치보다 낮고, 95% 신뢰구간은 현재 1을 포함하는 것을 볼수있음. 기저 과거력의 차이를 보정함으로써 비뚤림이 감소됌.

