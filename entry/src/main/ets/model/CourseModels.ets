export class Course {
  id: number = 0;
  name: string = '';
  dayOfWeek: number = 1;
  startMinutes: number = 540;
  endMinutes: number = 600;
  location: string = '';
  teacher: string = '';
  validFrom: number = 0;
  validUntil: number = 0;
  reminderMinutes: number = 30;
  isEnabled: boolean = true;
  createdAt: number = 0;
  updatedAt: number = 0;

  static create(name: string, dayOfWeek: number, startMinutes: number, endMinutes: number,
    location: string, teacher: string, reminderMinutes: number): Course {
    const course: Course = new Course();
    course.name = name;
    course.dayOfWeek = dayOfWeek;
    course.startMinutes = startMinutes;
    course.endMinutes = endMinutes;
    course.location = location;
    course.teacher = teacher;
    course.reminderMinutes = reminderMinutes;
    course.isEnabled = true;
    course.createdAt = Date.now();
    course.updatedAt = course.createdAt;
    return course;
  }
}

export class CourseOccurrence {
  course: Course = new Course();
  startAt: number = 0;
  endAt: number = 0;
  isCurrent: boolean = false;
}
