# College Bot Forecasts

###### NOTE: THIS FOLDER PROVIDED FOR REFERENCE ONLY. THIS WORK WAS NOT COMPLETED BY ME, IT WAS IN COLLABORATION WITH A TEAMMATE

- Forecasts were generated using a Random Forests model
- Predictors:
    - Student's GPA (transformed to a 0-1 scale)
    - Student's highest composite ACT score (transformed to a 0-1 scale)
    - Institution's average admission rate
    - Institution's average 25th percentile ACT/SAT score (transformed to a
    0-1 scale)
        - To account for schools that only reported one or the other, both
        the SAT and ACT were first transformed to a 0-1 scale, and the higher of
        the two was used as a predictor
- Per RTCC's request a model was also created on the following:
    - internal college rankings
    - student ethnicity
    - institutional HBCU status
    - student economic/FAFSA status (as defined by free lunch eligibility)
- The models do not differ significantly in performance. As of 2019-05-29,
the apply_forecasts.py generates forecasts for the Class of 2020 using the first
model
