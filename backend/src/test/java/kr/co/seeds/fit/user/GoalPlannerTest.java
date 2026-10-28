package kr.co.seeds.fit.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

import kr.co.seeds.fit.user.GoalPlanner.ActivityLevel;
import kr.co.seeds.fit.user.GoalPlanner.Input;
import kr.co.seeds.fit.user.GoalPlanner.Mode;
import kr.co.seeds.fit.user.GoalPlanner.Plan;
import kr.co.seeds.fit.user.GoalPlanner.Sex;

class GoalPlannerTest {

    private static Input male75(Mode mode, Double target, Integer weeks) {
        return new Input(Sex.MALE, 30, 175, 75, ActivityLevel.MODERATE, null, mode, target, weeks);
    }

    @Test
    void maintain_usesMifflinStJeor_whenNoBodyFat() {
        Plan p = GoalPlanner.plan(male75(Mode.MAINTAIN, null, null));
        // 10*75 + 6.25*175 - 5*30 + 5 = 1698.75
        assertThat(p.bmrFormula()).isEqualTo("MIFFLIN_ST_JEOR");
        assertThat(p.bmrKcal()).isEqualTo(1699);
        assertThat(p.tdeeKcal()).isEqualTo(2633);          // 1698.75 * 1.55
        assertThat(p.calorieTarget()).isEqualTo(2633);
        assertThat(p.proteinG()).isEqualTo(120);           // 1.6 * 75
        assertThat(p.weeklyWeightChangeKg()).isEqualTo(0.0);
        assertThat(p.warnings()).isEmpty();
        // 매크로 합 ≈ 칼로리
        int kcalFromMacros = p.proteinG() * 4 + p.carbG() * 4 + p.fatG() * 9;
        assertThat(kcalFromMacros).isBetween(p.calorieTarget() - 20, p.calorieTarget() + 20);
    }

    @Test
    void usesKatchMcArdle_whenBodyFatGiven() {
        Input in = new Input(Sex.MALE, 30, 175, 75, ActivityLevel.MODERATE, 15.0, Mode.MAINTAIN, null, null);
        Plan p = GoalPlanner.plan(in);
        // lean = 63.75 → 370 + 21.6*63.75 = 1747
        assertThat(p.bmrFormula()).isEqualTo("KATCH_MCARDLE");
        assertThat(p.bmrKcal()).isEqualTo(1747);
    }

    @Test
    void femaleFormula_subtracts161() {
        Input in = new Input(Sex.FEMALE, 28, 162, 55, ActivityLevel.LIGHT, null, Mode.MAINTAIN, null, null);
        Plan p = GoalPlanner.plan(in);
        // 550 + 1012.5 - 140 - 161 = 1261.5
        assertThat(p.bmrKcal()).isEqualTo(1262);
    }

    @Test
    void leanBulk_addsSurplus_andHigherProtein() {
        Plan p = GoalPlanner.plan(male75(Mode.LEAN_BULK, null, null));
        assertThat(p.calorieTarget()).isEqualTo(2962);     // 2633.06 * 1.125
        assertThat(p.proteinG()).isEqualTo(143);           // 1.9 * 75 = 142.5
        assertThat(p.weeklyWeightChangeKg()).isPositive();
    }

    @Test
    void cut_appliesLargerDeficit() {
        Plan p = GoalPlanner.plan(male75(Mode.CUT, null, null));
        assertThat(p.calorieTarget()).isEqualTo(2041);     // 2633.06 * 0.775
        assertThat(p.proteinG()).isEqualTo(173);           // 2.3 * 75 = 172.5
        assertThat(p.weeklyWeightChangeKg()).isNegative();
    }

    @Test
    void diet_reasonableGoal_hasNoWarnings() {
        // 75 → 71 kg, 8주 = 0.5 kg/주 = 0.67%/주, 일일 적자 550 kcal (TDEE의 21%→캡)
        Plan p = GoalPlanner.plan(male75(Mode.DIET, 71.0, 8));
        assertThat(p.calorieTarget()).isLessThan(p.tdeeKcal());
        assertThat(p.weeklyWeightChangeKg()).isLessThan(0);
        assertThat(p.warnings()).extracting("code").doesNotContain("TOO_FAST", "BELOW_FLOOR");
    }

    @Test
    void diet_tooFast_warnsAndSuggestsWeeks() {
        // 75 → 70 kg, 2주 = 2.5 kg/주 = 3.3%/주
        Plan p = GoalPlanner.plan(male75(Mode.DIET, 70.0, 2));
        assertThat(p.warnings()).extracting("code").contains("TOO_FAST");
        assertThat(p.suggestedWeeks()).isNotNull().isGreaterThanOrEqualTo(7); // 5kg / 0.75kg
        // 적자는 TDEE 20%로 캡
        assertThat(p.calorieTarget()).isGreaterThanOrEqualTo((int) (p.tdeeKcal() * 0.8) - 1);
    }

    @Test
    void female_belowFloor_clampsTo1200() {
        // 작은 체구 여성 + 컷팅 → 하한선 적용
        Input in = new Input(Sex.FEMALE, 35, 155, 48, ActivityLevel.SEDENTARY, null, Mode.CUT, null, null);
        Plan p = GoalPlanner.plan(in);
        assertThat(p.calorieTarget()).isEqualTo(GoalPlanner.CALORIE_FLOOR_FEMALE);
        assertThat(p.warnings()).extracting("code").contains("BELOW_FLOOR");
    }

    @Test
    void diet_requiresTarget() {
        assertThatThrownBy(() -> GoalPlanner.plan(male75(Mode.DIET, null, null)))
            .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> GoalPlanner.plan(male75(Mode.DIET, 80.0, 8)))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void fat_neverBelow0_8gPerKg() {
        Plan p = GoalPlanner.plan(male75(Mode.CUT, null, null));
        assertThat(p.fatG()).isGreaterThanOrEqualTo(60);   // 0.8 * 75
    }
}
