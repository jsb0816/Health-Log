package kr.co.seeds.fit.user;

import java.util.ArrayList;
import java.util.List;

/**
 * 목표 모드 계산기 (PLAN.md 2.7).
 * 순수 Java, 외부 의존 없음. 모든 영양 목표의 단일 진실(single source of truth).
 *
 * <ul>
 *   <li>BMR: 인바디(제지방량) 있으면 Katch-McArdle, 없으면 Mifflin-St Jeor</li>
 *   <li>TDEE: BMR × 활동계수 (앱이 기록한 운동 kcal은 별도 가산하므로 활동계수는 "비운동" 기준)</li>
 *   <li>모드별 칼로리·매크로, 성별 하한선, 감량 속도 안전 규칙</li>
 * </ul>
 */
public final class GoalPlanner {

    public enum Sex { MALE, FEMALE }

    public enum ActivityLevel {
        SEDENTARY(1.2), LIGHT(1.375), MODERATE(1.55), ACTIVE(1.725), VERY_ACTIVE(1.9);
        public final double factor;
        ActivityLevel(double factor) { this.factor = factor; }
    }

    public enum Mode { MAINTAIN, LEAN_BULK, DIET, CUT }

    /** 1 kg 체지방 ≈ 7,700 kcal */
    public static final double KCAL_PER_KG_FAT = 7700.0;
    public static final int CALORIE_FLOOR_FEMALE = 1200;
    public static final int CALORIE_FLOOR_MALE = 1500;
    /** 주당 체중 감량 상한 (체중 대비 %) */
    public static final double MAX_WEEKLY_LOSS_PCT = 1.0;
    /** 다이어트 모드 최대 적자 비율 */
    public static final double MAX_DIET_DEFICIT = 0.20;

    public record Input(
        Sex sex,
        int ageYears,
        double heightCm,
        double weightKg,
        ActivityLevel activityLevel,
        /** 인바디 체지방률(%). 없으면 null → Mifflin-St Jeor */
        Double bodyFatPct,
        Mode mode,
        /** DIET 모드에서만 사용 */
        Double targetWeightKg,
        Integer targetWeeks
    ) {}

    public record Warning(String code, String message) {}

    public record Plan(
        int bmrKcal,
        String bmrFormula,
        int tdeeKcal,
        int calorieTarget,
        int proteinG,
        int carbG,
        int fatG,
        /** 주당 목표 체중 변화 (kg, 음수=감량) */
        double weeklyWeightChangeKg,
        /** 하한선 등으로 조정됐을 때 권장 기간(주). 조정 없으면 null */
        Integer suggestedWeeks,
        List<Warning> warnings
    ) {}

    private GoalPlanner() {}

    public static Plan plan(Input in) {
        List<Warning> warnings = new ArrayList<>();

        // ---- BMR
        double bmr;
        String formula;
        if (in.bodyFatPct() != null && in.bodyFatPct() > 0 && in.bodyFatPct() < 70) {
            double leanMass = in.weightKg() * (1 - in.bodyFatPct() / 100.0);
            bmr = 370 + 21.6 * leanMass;
            formula = "KATCH_MCARDLE";
        } else {
            bmr = 10 * in.weightKg() + 6.25 * in.heightCm() - 5 * in.ageYears()
                + (in.sex() == Sex.MALE ? 5 : -161);
            formula = "MIFFLIN_ST_JEOR";
        }

        // ---- TDEE
        double tdee = bmr * in.activityLevel().factor;

        // ---- 모드별 칼로리 · 단백질 · 주간 변화
        double calories;
        double proteinPerKg;
        double weeklyChangeKg;
        Integer suggestedWeeks = null;

        switch (in.mode()) {
            case MAINTAIN -> {
                calories = tdee;
                proteinPerKg = 1.6;
                weeklyChangeKg = 0;
            }
            case LEAN_BULK -> {
                calories = tdee * 1.125;             // +10~15%
                proteinPerKg = 1.9;                  // 1.8~2.0
                weeklyChangeKg = in.weightKg() * 0.00375; // +0.25~0.5%/주
            }
            case DIET -> {
                proteinPerKg = 2.0;
                if (in.targetWeightKg() == null || in.targetWeeks() == null || in.targetWeeks() <= 0) {
                    throw new IllegalArgumentException("DIET 모드는 targetWeightKg, targetWeeks(>0)가 필요합니다");
                }
                double lossKg = in.weightKg() - in.targetWeightKg();
                if (lossKg <= 0) {
                    throw new IllegalArgumentException("DIET 모드의 목표 체중은 현재 체중보다 작아야 합니다");
                }
                double weeklyLoss = lossKg / in.targetWeeks();
                double weeklyLossPct = weeklyLoss / in.weightKg() * 100;
                if (weeklyLossPct > MAX_WEEKLY_LOSS_PCT) {
                    int minWeeks = (int) Math.ceil(lossKg / (in.weightKg() * MAX_WEEKLY_LOSS_PCT / 100));
                    warnings.add(new Warning("TOO_FAST",
                        String.format("주당 %.2f%% 감량은 너무 빠릅니다. 최소 %d주를 권장합니다.", weeklyLossPct, minWeeks)));
                    suggestedWeeks = minWeeks;
                }
                double dailyDeficit = weeklyLoss * KCAL_PER_KG_FAT / 7;
                double maxDeficit = tdee * MAX_DIET_DEFICIT;
                if (dailyDeficit > maxDeficit) {
                    dailyDeficit = maxDeficit;
                    int weeksAtMax = (int) Math.ceil(lossKg * KCAL_PER_KG_FAT / (maxDeficit * 7));
                    if (suggestedWeeks == null || weeksAtMax > suggestedWeeks) suggestedWeeks = weeksAtMax;
                    warnings.add(new Warning("DEFICIT_CAPPED",
                        String.format("일일 적자를 TDEE의 %.0f%%로 제한했습니다. 이 속도면 약 %d주가 걸립니다.",
                            MAX_DIET_DEFICIT * 100, weeksAtMax)));
                }
                calories = tdee - dailyDeficit;
                weeklyChangeKg = -(dailyDeficit * 7 / KCAL_PER_KG_FAT);
            }
            case CUT -> {
                calories = tdee * 0.775;             // −20~25%
                proteinPerKg = 2.3;                  // 2.2~2.4
                weeklyChangeKg = -(tdee * 0.225 * 7 / KCAL_PER_KG_FAT);
            }
            default -> throw new IllegalStateException("unknown mode " + in.mode());
        }

        // ---- 성별 칼로리 하한선
        int floor = in.sex() == Sex.FEMALE ? CALORIE_FLOOR_FEMALE : CALORIE_FLOOR_MALE;
        if (calories < floor) {
            warnings.add(new Warning("BELOW_FLOOR",
                String.format("계산된 %d kcal은 %s 하한선 %d kcal보다 낮아 하한선으로 조정했습니다.",
                    (int) Math.round(calories), in.sex() == Sex.FEMALE ? "여성" : "남성", floor)));
            double actualDeficit = Math.max(0, tdee - floor);
            weeklyChangeKg = in.mode() == Mode.LEAN_BULK ? weeklyChangeKg : -(actualDeficit * 7 / KCAL_PER_KG_FAT);
            if (in.mode() == Mode.DIET && actualDeficit > 0) {
                double lossKg = in.weightKg() - in.targetWeightKg();
                int weeksAtFloor = (int) Math.ceil(lossKg * KCAL_PER_KG_FAT / (actualDeficit * 7));
                if (suggestedWeeks == null || weeksAtFloor > suggestedWeeks) suggestedWeeks = weeksAtFloor;
            }
            calories = floor;
        }

        // ---- 매크로: 단백질 g/kg, 지방 = max(0.8 g/kg, 25% kcal), 탄수 = 잔여
        double proteinG = proteinPerKg * in.weightKg();
        double fatG = Math.max(0.8 * in.weightKg(), calories * 0.25 / 9);
        double carbG = (calories - proteinG * 4 - fatG * 9) / 4;
        if (carbG < 50) {
            warnings.add(new Warning("LOW_CARB",
                "칼로리 목표가 낮아 탄수화물이 50 g 미만입니다. 지방을 최소치로 낮추거나 기간을 늘리세요."));
            fatG = 0.8 * in.weightKg();
            carbG = Math.max(0, (calories - proteinG * 4 - fatG * 9) / 4);
        }

        return new Plan(
            (int) Math.round(bmr),
            formula,
            (int) Math.round(tdee),
            (int) Math.round(calories),
            (int) Math.round(proteinG),
            (int) Math.round(carbG),
            (int) Math.round(fatG),
            Math.round(weeklyChangeKg * 100) / 100.0,
            suggestedWeeks,
            List.copyOf(warnings)
        );
    }
}
