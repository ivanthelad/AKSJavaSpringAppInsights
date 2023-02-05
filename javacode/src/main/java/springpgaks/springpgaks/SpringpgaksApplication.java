package springpgaks.springpgaks;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import com.microsoft.applicationinsights.attach.ApplicationInsights;

@SpringBootApplication
public class SpringpgaksApplication {

	public static void main(String[] args) {
		ApplicationInsights.attach();

		SpringApplication.run(SpringpgaksApplication.class, args);
	}

}
