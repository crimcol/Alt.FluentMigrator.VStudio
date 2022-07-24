var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/items", () => "Hello world");

app.Run();
