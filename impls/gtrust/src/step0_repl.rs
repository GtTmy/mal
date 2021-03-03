use std::io;
use std::io::Write;


fn read() -> Option<String> {
    print!("user>");
    io::stdout().flush().unwrap(); 
    let mut input = String::new();
    match io::stdin().read_line(&mut input) {
        Ok(c) => {
            if c == 0 {
                return None;
            }
        },
        Err(_) => panic!("Error!")
    }
    input.retain(|c| c!='\n');
    Some(input)
}

fn eval(expr: &str) -> String {
    expr.to_string()
}

fn print_result(result: &str) {
    println!("{}", result);
}

enum GtRustError
{ 
    Aborted,
}

fn rep() -> Result<(), GtRustError> {
    match read() {
        Some(l) => { 
            print_result(&eval(&l));
            return Ok(());
        }
        None => return Err(GtRustError::Aborted),
    }
}

fn main() {
    loop {
        if let Err(_) = rep() {
            return;
        }
    }
}
