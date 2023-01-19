package springpgaks.springpgaks.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import springpgaks.springpgaks.model.Employee;

@Repository
public interface EmployeeRepository extends JpaRepository<Employee, Long>{

}