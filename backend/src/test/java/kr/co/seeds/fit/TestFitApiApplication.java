package kr.co.seeds.fit;

import org.springframework.boot.SpringApplication;

public class TestFitApiApplication {

	public static void main(String[] args) {
		SpringApplication.from(FitApiApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
