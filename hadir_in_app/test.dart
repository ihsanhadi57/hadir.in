void main() {
  dynamic a = "Hello";
  try {
    print(a['message']);
  } catch (e) {
    print(e.runtimeType);
    print(e);
  }
}
