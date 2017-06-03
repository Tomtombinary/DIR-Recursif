// DIR-recursif.cpp : définit le point d'entrée pour l'application console.
//

#include "stdafx.h"
#include <Windows.h>

#define SEARCH_ALL L"\\*"

void ListDirectory(LPCWSTR directory);
void PrintLastError();
BOOL BuildSearchCommand(WCHAR* buffer, DWORD nBufferLength,WCHAR* directoryFullPath);

/* Point d'entrée du programme */

int _tmain(int argc, TCHAR* argv[])
{
	/* Vérification du nombre d'arguments */
	if (argc == 2)
		ListDirectory(argv[1]);
	/* Sinon on affiche l'aide */
	else
		wprintf(L"Usage : %s <directory>\n",argv[0]);
	return 0;
}

BOOL BuildSearchCommand(WCHAR* buffer, DWORD nBufferLength,WCHAR* directoryFullPath)
{
	BOOL success = FALSE;

	ZeroMemory(buffer, nBufferLength * sizeof(WCHAR));

	wcsncpy(buffer, directoryFullPath,nBufferLength - 1);
	// wprintf(L"len(\"%ws\")=%d\n",SEARCH_ALL,sizeof(SEARCH_ALL));
	if (wcslen(buffer) - sizeof(SEARCH_ALL) < nBufferLength)
	{
		wcscat(buffer, SEARCH_ALL);
		success = TRUE;
	}

	return success;
}

/* Liste récursivement le répertoire passé en paramètre */
void ListDirectory(LPCWSTR directory)
{	
	/* Buffer pour la concaténation du répertoire + \* */
	WCHAR search[MAX_PATH];
	/* Chemin absolu du répertoire */
	WCHAR directoryFullPath[MAX_PATH];
	/* Information sur le fichier courrant (FindFirstFile,FindNextFile) */
	WIN32_FIND_DATAW currentFileData;
	/* Date au format jour mois année du fichier courrant */
	SYSTEMTIME currentSystemTime;

	/* Récupère le chemin absolu du répértoire */
	GetFullPathNameW(directory, MAX_PATH, directoryFullPath,NULL);
	/* Change le répertoire de travail */
	SetCurrentDirectoryW(directory);
	
	/* Effectue la concaténation du répertoire + \* */
	if (!BuildSearchCommand(search, MAX_PATH, directoryFullPath))
	{
		wprintf(L"Nom de r\202pertoire trop long\n");
		return;
	}

	wprintf(L"\nR\202pertoire de %ws\n\n", directoryFullPath);

	/* Trouve le premier fichier du répertoire à lister */
	HANDLE hListDirectory = FindFirstFileW(search, &currentFileData);
	if (hListDirectory != INVALID_HANDLE_VALUE)
	{
		do
		{
			/* Converti la structure de type FILETIME en structure de type SYSTEMTIME */
			if (FileTimeToSystemTime(&currentFileData.ftCreationTime, &currentSystemTime))
			{
				/* Si le fichier est un répertoire */
				if (currentFileData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
				{
					/* On affiche les informations et <REP> */
					wprintf(L"%02.2d/%02.2d/%04.4d  %02.2d:%02.2d   <REP>  %ws\n", currentSystemTime.wDay, currentSystemTime.wMonth, currentSystemTime.wYear, currentSystemTime.wHour, currentSystemTime.wMinute, currentFileData.cFileName);
					/* Avant de lister le répertoire fils on verifie que celui-ci n'est pas le répertoire courrant ou le répertoire parent */
					if (wcsncmp(currentFileData.cFileName,L".", MAX_PATH) != 0 && wcsncmp(currentFileData.cFileName,L"..", MAX_PATH) != 0)
					{
						/* On liste le répertoire fils */
						ListDirectory(currentFileData.cFileName);
						/* On se replace dans le répertoire courrant */
						SetCurrentDirectoryW(directoryFullPath);
					}
				}
				else
				{
					/* Sinon on afficher les informations sur le fichier */
					printf("%02.2d/%02.2d/%04.4d  %02.2d:%02.2d          %ws\n", currentSystemTime.wDay, currentSystemTime.wMonth, currentSystemTime.wYear, currentSystemTime.wHour, currentSystemTime.wMinute, currentFileData.cFileName);
				}
			}
			/* On passe au fichier suivant */
		} while (FindNextFileW(hListDirectory, &currentFileData) != 0);
		/* On a fini de lister le répertoire, on ferme le handle */
		FindClose(hListDirectory);
	}
	else
	{
		/* Quelque chose c'est mal passé on affiche le message d'erreur */
		wprintf(L"FindFirstFileW(\"%ws\",%p) - failed\n",search,&currentFileData);
		PrintLastError();
	}
}

void PrintLastError()
{
	DWORD dLastError = GetLastError();
	LPCTSTR strErrorMessage = NULL;

	FormatMessage(
		FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS | FORMAT_MESSAGE_ARGUMENT_ARRAY | FORMAT_MESSAGE_ALLOCATE_BUFFER,
		NULL,
		dLastError,
		0,
		(LPWSTR)&strErrorMessage,
		0,
		NULL);

	fwprintf(stderr,L"%ws\n", strErrorMessage);
}

