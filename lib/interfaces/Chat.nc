interface Chat
{
    command error_t connectToServer(uint8_t* username, uint16_t address, uint8_t port);
    command error_t startServer(uint8_t port);
    command error_t receive(pack* package);
}